#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import strformat
import nile
import os

const VIEWPORT_RESOLUTION = 512
const TILE_RESOLUTION = 2048
const SEED = 9

const PALETTE = @[
    000, 0x001070 , # Dark Blue
    126, 0x2C5A7C , # Light Blue
    127, 0xE0F0A0 , # Yellow
    128, 0x5D943C , # Dark Green
    160, 0x606011 , # Brown
    200, 0xFFFFFF , # White
    255, 0xFFFFFF ] # White

proc showPNG(fname: string): void =
    discard execShellCmd fmt"imgcat {fname}"

let
    tile = generateRootTile(TILE_RESOLUTION, SEED)
    island = tile.mask
    small = island.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    image = newImageFromLuminance(small)
    gradient = newColorGradient(PALETTE)
    fname = fmt"island.png"

discard createEdt(tile.mask)

image.applyColorGradient(gradient)
image.savePNG(fname)
showPNG(fname)
