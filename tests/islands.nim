#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import strformat
import nile
import os

const VIEWPORT_RESOLUTION = 256
const TILE_RESOLUTION = 2048

const SMOOTH_PALETTE = @[
    000, 0x001070 , # Dark Blue
    126, 0x2C5A7C , # Light Blue
    127, 0xE0F0A0 , # Yellow
    128, 0x5D943C , # Dark Green
    160, 0x606011 , # Brown
    200, 0xFFFFFF , # White
    255, 0xFFFFFF ] # White

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

# Generate a "radiating" palette at compile time.
proc makeGray: seq[int] =
    result = newSeq[int]()
    var i = 0
    while i < 120:
        result.add(i); result.add(0xFFFFFF)
        i += 4
        let
            r = 200 - i * 2
            c = r or (r shl 8) or (r shl 16)
        result.add(i); result.add(c)
        result.add(i); result.add(0xFFFFFF)
        i += 15
    result.add(127); result.add(0x900000)
    result.add(128); result.add(0x900000)
    result.add(129); result.add(0x909090)
    result.add(255); result.add(0x707070)
const GRAY_PALETTE = makeGray()

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

proc showPNG(fname: string): void =
    if 0 == execShellCmd fmt"which -s imgcat":
        discard execShellCmd fmt"imgcat {fname}"
    else:
        echo fmt"Generated {fname}"

proc genIsland(palette: seq[int], seed: int): Image =
    let
        tile = generateRootTile(TILE_RESOLUTION, seed)
        gradient = newColorGradient(palette)
        el = tile.distance - tile.offset

    # Apply some of the noise to the SDF before rendering.
    for i in 0..<el.data.len():
        el.data[i] -= 0.5 * el.data[i] * tile.noise.data[i]

    var image = newImageFromLuminance(0.5 + el)
    image.applyColorGradient(gradient)
    image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    image

let
    island0 = genIsland(STEPPED_PALETTE, 9)
    island1 = genIsland(SMOOTH_PALETTE, 22)
    island2 = genIsland(GRAY_PALETTE, 1)
    image = hstack(island0, island1, island2)
    fname = fmt"islands.png"

image.drawGrid(3, 1)
image.savePNG(fname)
showPNG(fname)
