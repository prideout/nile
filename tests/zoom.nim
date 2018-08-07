#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import strformat
import nile
import os

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

proc showPNG(fname: string): void =
    if 0 == execShellCmd fmt"which -s imgcat":
        discard execShellCmd fmt"imgcat {fname}"
    else:
        echo fmt"Generated {fname}"

proc render(tile: Tile, fname: string, gradient: ColorGradient): void =
    var image = newImageFromLuminance(tile.elevation)
    image.applyColorGradient(gradient)
    image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    image.drawGrid(1, 1)
    image.savePNG(fname)
    showPNG(fname)

let
    gradient = newColorGradient(STEPPED_PALETTE)
    parent = generateRootTile(TILE_RESOLUTION, SEED)
    child = generateChild(parent, (0'i64, 0'i64, 1'i64))
render(parent, fmt"frame-000.png", gradient)
render(child, fmt"frame-001.png", gradient)
