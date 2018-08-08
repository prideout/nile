#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import math
import nile
import os
import strformat

const NFRAMES = 12
const VIEWPORT_RESOLUTION = 256
const TILE_RESOLUTION = 2048
const SEED = 3
const STEPPED_PALETTE = @[
    000, 0x2C316F ,
    125, 0x2C316F ,
    125, 0x46769D ,
    126, 0x46769D ,
    127, 0x324060 ,
    131, 0x324060 ,
    132, 0x9C907D ,
    137, 0x9C907D ,
    137, 0x719457 ,
    155, 0x719457 , # Light green
    155, 0x50735A ,
    180, 0x50735A ,
    180, 0x9FA881 ,
    200, 0x9FA881 ,
    200, 0xFFFFFF ,
    255, 0xFFFFFF ]

# Show the given PNG image if the platform supports it.
proc showPNG(fname: string): void =
    if 0 == execShellCmd fmt"which -s imgcat":
        discard execShellCmd fmt"imgcat {fname}"
    else:
        echo fmt"Generated {fname}"

# Convert a grid-of-floats into a colorful PNG image.
proc render(tile: Tile, fname: string, gradient: ColorGradient): void =
    var image = newImageFromLuminance(tile.elevation)
    image.applyColorGradient(gradient)
    image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    image.savePNG(fname)
    showPNG(fname)

# Find a quadrant that contains coastline.
var flip = true
proc chooseChild(parent: Tile): Vec3ii =
    var results = newSeq[Vec3ii]()
    let
        x = parent.index.x * 2
        y = parent.index.y * 2
        z = parent.index.z + 1
        el = parent.elevation
        (w2, h2) = (el.width, el.height)
        (w1, h1) = (int(w2 / 2), int(h2 / 2))
        isBest = proc(l, t, r, b: int): bool =
            let 
                quadrant = el.crop(l, t, r, b)
                (lo, hi) = (quadrant.min(), quadrant.max())
            sgn(lo - 0.5) != sgn(hi - 0.5)
    if isBest(00, 00, w1, h1): results.add (x+0, y+0, z)
    if isBest(w1, 00, w2, h1): results.add (x+1, y+0, z)
    if isBest(00, h1, w1, h2): results.add (x+0, y+1, z)
    if isBest(w1, h1, w2, h2): results.add (x+1, y+1, z)
    if results.len() == 0:
        echo "No coastline."
        quit()
    flip = not flip
    if flip: results[0] else: results[results.len() - 1]

if isMainModule:
    let gradient = newColorGradient(STEPPED_PALETTE)
    var tile = generateRootTile(TILE_RESOLUTION, SEED)
    echo tile.index
    render(tile, fmt"frame-000.png", gradient)
    for frame in 1..NFRAMES:
        let childIndex = chooseChild(tile)
        echo childIndex
        tile = generateChild(tile, childIndex)
        render(tile, fmt"frame-{frame:03}.png", gradient)
