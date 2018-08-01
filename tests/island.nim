#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import nile
import nimPNG

proc savePNG(g: Grid, filename: string): void =
    discard savePNG(filename, g.toDataString(), LCT_GREY, 8, g.width, g.height)

proc savePNG(img: Image, filename: string): void =
    discard savePNG(filename, img.toDataString(), LCT_RGBA, 8, img.width, img.height)

proc marchSegment(grid: Grid, p0: Vec2f, p1: Vec2f): Vec2f =
    let delta = 1 / float(max(grid.width, grid.height))
    echo "marchSegment is TBD"
    return (0.5f, 0.5f)

proc genIsland(seed: int, size: int = 128): Grid =
    let
        s2 = size * 2
        splat = newGrid("000 010 000").resize(s2, s2, FilterHermite)
        g = ((
            generateGradientNoise(seed, s2, s2, 4.0f) +
            generateGradientNoise(seed, s2, s2, 8.0f) / 2 +
            generateGradientNoise(seed, s2, s2, 16.0f) / 4 +
            generateGradientNoise(seed, s2, s2, 32.0f) / 8) +
            splat * 0.5) * splat
        r0 = int(float(size) - size / 2)
        r1 = int(float(size) + size / 2)
        g2 = g.step(0.1) * 0.7 + 0.1
    return g2.crop(r0, r0, r1, r1)

proc genIslands(): void =
    var isles: array[8, Grid]
    for seed in 0..<isles.len():
        isles[seed] = genIsland seed
    let
        row0 = hstack(isles[0], isles[1], isles[2], isles[3])
        row1 = hstack(isles[4], isles[5], isles[6], isles[7])
    vstack(row0, row1).drawGrid(4, 2, 0.3f).savePNG("islands.png")

genIslands()

let
    island = genIsland(9, 320)
    p0 = (0.6f, 0.0f)
    p1 = (0.4f, 1.0f)
    pt = island.marchSegment(p0, p1)
    canvas = newCanvas(320, 320)

canvas.setColor(0.0, 1.0, 0.0, 0.5).moveTo(p0).lineTo(p1).stroke()
canvas.setColor(0.1, 0.1, 0.1, 1.0).circle(pt, radius = 0.01).fill()

newImageFromLuminance(island).addOverlay(canvas.toImage()).savePNG("big.png")
