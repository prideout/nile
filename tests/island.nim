#!/usr/bin/env nim c --debugger:native --run

#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import cairo
import nimPNG
import nile

# Exports the floating-point data by clamping to [0, 1] and scaling to 255.
proc savePNG(g: Grid, filename: string): void =
    let npixels = g.width * g.height
    var u8data = newString(npixels)
    for i in 0..<npixels:
        let v = g.data[i].clamp(0, 1)
        u8data[i] = chr(int(v * 255))
    discard savePNG(filename, u8data, LCT_GREY, 8, g.width, g.height)

let splat = newGrid("000 010 000").resize(256, 256, FilterHermite)

proc genIsland(seed: int): Grid =
    let g = ((
        generateGradientNoise(seed, 256, 256, 4.0f) +
        generateGradientNoise(seed, 256, 256, 8.0f) / 2 +
        generateGradientNoise(seed, 256, 256, 16.0f) / 4 +
        generateGradientNoise(seed, 256, 256, 32.0f) / 8) +
        splat * 0.5) * splat
    return g.step(0.1) * 0.7 + 0.1

let
    r0 = 128 - 64
    r1 = 128 + 64
    a0 = genIsland(0).crop(r0, r0, r1, r1)
    b0 = genIsland(1).crop(r0, r0, r1, r1)
    c0 = genIsland(2).crop(r0, r0, r1, r1)
    d0 = genIsland(3).crop(r0, r0, r1, r1)
    a1 = genIsland(4).crop(r0, r0, r1, r1)
    b1 = genIsland(5).crop(r0, r0, r1, r1)
    c1 = genIsland(6).crop(r0, r0, r1, r1)
    d1 = genIsland(7).crop(r0, r0, r1, r1)

vstack(hstack(a0, b0, c0, d0), hstack(a1, b1, c1, d1))
    .drawGrid(4, 2, 0.3f).savePNG("islands.png")

type
    Canvas* = ref object
        data*: string
        width*, height*: int
        surface: PSurface
        context: PContext

proc newCanvas(width, height: int): Canvas =
    new(result)
    result.data = newString(width * height * 4)
    result.width = width
    result.height = height
    let
        w32 = int32(width)
        h32 = int32(height)
        stride = int32(width * 4)
    result.surface = image_surface_create(cstring(result.data), FORMAT_ARGB32, w32, h32, stride)
    result.context = result.surface.create()

proc savePNG(c: Canvas, filename: string): void =
    discard savePNG(filename, c.data, LCT_RGBA, 8, c.width, c.height)

let
    canvas = newCanvas(256, 256)
    cr = canvas.context
cr.set_line_width(2)
cr.rectangle(20, 20, 100, 100)
cr.set_source_rgb(0.8, 0.6, 0.6)
cr.fill_preserve
cr.set_source_rgb(0.3, 0.3, 0.8)
cr.stroke
canvas.savePNG("cairotest.png")
