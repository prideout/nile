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
    if 0 == execShellCmd fmt"which -s imgcat":
        discard execShellCmd fmt"imgcat {fname}"
    else:
        echo fmt"Generated {fname}"

let
    tile = generateRootTile(TILE_RESOLUTION, SEED)
    gradient = newColorGradient(PALETTE)
    fname = fmt"island.png"
    edt = createSdf(tile.mask)
    lower = abs(min(edt))
    upper = abs(max(edt))

var image = newImageFromLuminance(0.5 + 0.5 * edt / max(upper, lower))
image.applyColorGradient(gradient)
image.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
image.savePNG(fname)
showPNG(fname)
