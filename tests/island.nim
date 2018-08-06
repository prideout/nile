#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import strformat
import nile
import os

const VIEWPORT_RESOLUTION = 128
const TILE_RESOLUTION = 256
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
    gradient = newColorGradient(PALETTE)
    fname = fmt"island.png"
    edt = createEdt(tile.mask)

var image = newImageFromLuminance(edt / max(edt))
image.applyColorGradient(gradient)
# image = image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
image.savePNG(fname)
showPNG(fname)
