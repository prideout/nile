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
