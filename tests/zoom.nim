#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import math
import nile
import os
import strformat

const NFRAMES = 20
const VIEWPORT_RESOLUTION = 320
const TILE_RESOLUTION = 1024
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

type Map = ref object
    resolution: int
    seed: int

type Tile = ref object
    distance*: Grid
    mask*: Grid
    noise*: Grid
    elevation*: Grid
    index*: Vec3ii
    offset*: float
    map: Map
    children: array[4, Tile]

proc generateFalloff(size: int, view: Viewport): Grid =
    result = newGrid(size, size)
    let
        dx = (view.right - view.left) / float32(size)
        dy = (view.bottom - view.top) / float32(size)
    var y = view.top
    var i = 0
    for row in 0..<size:
        var x = view.left
        for col in 0..<size:
            let
                t = len((x,y) - (0.5f, 0.5f))
                v = FilterHermite.function(t)
            result.data[i] = v * v * v
            inc i
            x += dx
        y += dy

proc generateRootTile(resolution, seed: int): Tile =
    let
        size = resolution
        view = ENTIRE
        falloff = generateFalloff(size, view)
        vp0 = view * 4.0f
        vp1 = vp0 * 2.0f
        vp2 = vp1 * 2.0f
        vp3 = vp2 * 2.0f
        vp4 = vp3 * 2.0f
    new(result)
    result.index = (0'i64, 0'i64, 0'i64)
    result.map = new Map
    result.map.resolution = resolution
    result.map.seed = seed
    var g = generateGradientNoise(seed, size, size, vp0)
    g *= 2.0f
    g += generateGradientNoise(seed + 1, size, size, vp1)
    g *= 2.0f
    g += generateGradientNoise(seed + 2, size, size, vp2)
    g *= 2.0f
    g += generateGradientNoise(seed + 3, size, size, vp3)
    g *= 2.0f
    g += generateGradientNoise(seed + 4, size, size, vp4)
    g /= 16
    g += falloff / 2
    g *= falloff
    result.noise = g * 1.0
    result.mask = g.step(0.1)
    g = createSdf(result.mask)
    result.offset = 0.0
    var
        lower = min(g)
        upper = max(g)
    result.distance = (g - lower) / (upper - lower)
    result.offset = (result.offset - lower) / (upper - lower)
    result.elevation = result.distance - result.offset
    result.elevation -= 0.5 * result.elevation * result.noise
    result.elevation += 0.5

proc generateChild(child: Tile, parent: Tile, subview: Viewport): void =
    let
        map = child.map
        zoom = child.index.z
        seed = map.seed + int(zoom)
        size = map.resolution
        fsize = float(size)
        left = int(subview.left * fsize)
        top = int(subview.top * fsize)
        right = int(subview.right * fsize)
        bottom = int(subview.bottom * fsize)
    child.offset = parent.offset
    child.mask = parent.mask.crop(left, top, right, bottom).resize(size, size, FilterGaussian)
    let g = createSdf(child.mask)
    let (lower, upper) = (min(g), max(g))
    child.distance = (g - lower) / (upper - lower)
    child.offset = (0.0 - lower) / (upper - lower)
    child.noise = 0.0125 * generateGradientNoise(seed, size, size, ENTIRE * 16.0)
    child.distance += child.noise
    child.mask = child.distance.step(child.offset)
    child.elevation = child.distance - child.offset
    child.elevation -= 5.0 * child.elevation * child.noise # <== This doesn't really do much.
    child.elevation += 0.5

proc generateChild(parent: Tile, index: Vec3ii): Tile =
    assert(index.z == parent.index.z + 1)
    let
        west = parent.index.x * 2
        east = west + 1
        north = parent.index.y * 2
        south = north + 1
    result = new Tile
    result.index = index
    result.map = parent.map
    if index.x == west and index.y == north:
        parent.children[0] = result
        generateChild(result, parent, (0.0f, 0.0f, 0.5f, 0.5f))
    elif index.x == east and index.y == north:
        parent.children[1] = result
        generateChild(result, parent, (0.5f, 0.0f, 1.0f, 0.5f))
    elif index.x == west and index.y == south:
        parent.children[2] = result
        generateChild(result, parent, (0.0f, 0.5f, 0.5f, 1.0f))
    elif index.x == east and index.y == south:
        parent.children[3] = result
        generateChild(result, parent, (0.5f, 0.5f, 1.0f, 1.0f))
    else:
        echo fmt"Cannot generate child {index.x:03} {index.y:03} {index.z:03}"
        assert(false)

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
