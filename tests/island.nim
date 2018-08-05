#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import strformat
import nile
import os

const VIEWPORT_RESOLUTION = 256
const TILE_RESOLUTION = 2048
const SEED = 9

proc showPNG(fname: string): void =
    discard execShellCmd fmt"imgcat {fname}"

let
    tile = generateRootTile(TILE_RESOLUTION, SEED)
    island = tile.mask
    small = island.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    im = newImageFromLuminance(small)
    fname = fmt"island.png"

im.savePNG(fname)
showPNG(fname)
