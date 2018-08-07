#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import strformat
import nile
import os

const VIEWPORT_RESOLUTION = 384
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

proc showPNG(fname: string): void =
    if 0 == execShellCmd fmt"which -s imgcat":
        discard execShellCmd fmt"imgcat {fname}"
    else:
        echo fmt"Generated {fname}"

let
    tile = generateRootTile(TILE_RESOLUTION, SEED)
    gradient = newColorGradient(STEPPED_PALETTE)

var image = newImageFromLuminance(0.5 + tile.elevation - tile.offset)
image.applyColorGradient(gradient)
image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)

let fname = fmt"island.png"
image.drawGrid(1, 1)
image.savePNG(fname)
showPNG(fname)
