#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import strformat
import nile
import os

const VIEWPORT_RESOLUTION = 512
const TILE_RESOLUTION = 2048
const SEED = 9

const SMOOTH_PALETTE* = @[
    000, 0x001070 , # Dark Blue
    126, 0x2C5A7C , # Light Blue
    127, 0xE0F0A0 , # Yellow
    128, 0x5D943C , # Dark Green
    160, 0x606011 , # Brown
    200, 0xFFFFFF , # White
    255, 0xFFFFFF ] # White

const STEPPED_PALETTE* = @[
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

proc showPNG(fname: string): void =
    if 0 == execShellCmd fmt"which -s imgcat":
        discard execShellCmd fmt"imgcat {fname}"
    else:
        echo fmt"Generated {fname}"

let
    tile = generateRootTile(TILE_RESOLUTION, SEED)
    gradient = newColorGradient(STEPPED_PALETTE)
    fname = fmt"island.png"
    n = tile.elevation
    edt = createSdf(tile.mask)

for i in 0..<edt.data.len():
    if edt.data[i] > 0.01:
        edt.data[i] -= edt.data[i] * n.data[i]

let
    lower = abs(min(edt))
    upper = abs(max(edt))

var image = newImageFromLuminance(0.5 + edt / max(upper, lower))
image.applyColorGradient(gradient)
image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
image.savePNG(fname)
showPNG(fname)
