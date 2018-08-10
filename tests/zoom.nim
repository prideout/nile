#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import math
import nile
import os
import strformat

const NFRAMES = 40
const VIEWPORT_RESOLUTION = 320
const TILE_RESOLUTION = 2048
const SEED = 3
const ZOOM_SPEED = 0.025
const SMOOTH_PALETTE = @[
    000, 0x001070 , # Dark Blue
    126, 0x2C5A7C , # Light Blue
    127, 0xE0F0A0 , # Yellow
    129, 0x5D943C , # Green
    140, 0x5D943C , # Green
    160, 0x606011 , # Brown
    255, 0xFFFFFF ] # White

# Show the given PNG image if the platform supports it.
proc showPNG(fname: string): void =
    if 0 == execShellCmd fmt"which -s imgcat":
        discard execShellCmd fmt"imgcat {fname}"
    else:
        echo fmt"Generated {fname}"

# Find a quadrant that contains coastline and a good distribution of landmass vs water.
proc chooseChild(parent: Tile): Vec3ii =
    var results = newSeq[Vec3ii]()
    let
        x = parent.index.x * 2
        y = parent.index.y * 2
        z = parent.index.z + 1
        el = parent.elevation
        (w2, h2) = (el.width, el.height)
        (w1, h1) = (int(w2 / 2), int(h2 / 2))
    var bestAverage = 100.0f
    let isBest = proc(l, t, r, b: int): bool =
        let
            quadrant = el.crop(l, t, r, b)
            (lo, hi) = (quadrant.min(), quadrant.max())
            avg = abs(quadrant.avg() - 0.5)
            hasCoast = sgn(lo - 0.5) != sgn(hi - 0.5)
        if avg < bestAverage and hasCoast:
            bestAverage = avg
            return true
        return false
    if isBest(00, 00, w1, h1): results.add (x+0, y+0, z)
    if isBest(w1, 00, w2, h1): results.add (x+1, y+0, z)
    if isBest(00, h1, w1, h2): results.add (x+0, y+1, z)
    if isBest(w1, h1, w2, h2): results.add (x+1, y+1, z)
    if results.len() == 0:
        echo "No coastline."
        quit()
    results[results.len() - 1]

let gradient = newColorGradient(SMOOTH_PALETTE)

# Convert an entire grid-of-floats into a colorful PNG image.
proc renderEntire(tile: Tile, fname: string): void =
    var image = newImageFromLuminance(tile.elevation)
    image.applyColorGradient(gradient)
    image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    image.savePNG(fname)
    showPNG(fname)

# Convert a portion of a grid-of-floats into a colorful PNG image.
proc renderPartial(tile: Tile, fname: string, vp: Viewport): void =
    var image = newImageFromLuminance(tile.elevation).crop(vp)
    image.applyColorGradient(gradient)
    image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    image.savePNG(fname)

# Lerp the viewport from an entire tile to one of its quadrants.
proc smoothZoom(tile: Tile, targetIndex: Vec3ii, frame: var int): int =
    var vp: Viewport = (0.0f, 0.0f, 1.0f, 1.0f)
    let
        amt = ZOOM_SPEED
        (parent, child) = (tile.index, targetIndex)
        nw = child.x == parent.x * 2 + 0 and child.y == parent.y * 2 + 0
        ne = child.x == parent.x * 2 + 1 and child.y == parent.y * 2 + 0
        sw = child.x == parent.x * 2 + 0 and child.y == parent.y * 2 + 1
        se = child.x == parent.x * 2 + 1 and child.y == parent.y * 2 + 1
    while (vp.right - vp.left) > 0.5:
        if nw: vp.right -= amt; vp.bottom -= amt
        if ne: vp.left += amt; vp.bottom -= amt
        if sw: vp.right -= amt; vp.top += amt
        if se: vp.left += amt; vp.top += amt
        renderPartial(tile, fmt"frame-{frame:03}.png", vp)
        inc frame
    return frame

if isMainModule:
    var tile = generateRootTile(TILE_RESOLUTION, SEED)
    echo tile.index
    var frame = 0
    renderEntire(tile, fmt"frame-{frame:03}.png")
    inc frame
    for zoom in 1..NFRAMES:
        let childIndex = chooseChild(tile)
        echo childIndex
        frame = smoothZoom(tile, childIndex, frame)
        tile = generateChild(tile, childIndex)
        renderEntire(tile, fmt"frame-{frame:03}.png")
        inc frame

    discard execShellCmd "ffmpeg -i frame-%03d.png -c:v mpeg4 -vb 150M video.mp4"
    discard execShellCmd "rm frame*.png"
