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

let
    a0 = genIsland(0)
    b0 = genIsland(1)
    c0 = genIsland(2)
    d0 = genIsland(3)
    a1 = genIsland(4)
    b1 = genIsland(5)
    c1 = genIsland(6)
    d1 = genIsland(7)

vstack(hstack(a0, b0, c0, d0), hstack(a1, b1, c1, d1))
    .drawGrid(4, 2, 0.3f).savePNG("islands.png")

type
    Canvas* = ref object
        data*: string
        width*, height*: int
        surface: PSurface
        context: PContext
    Image* = ref object
        width*, height*: int
        grids: seq[Grid]
        format: string

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

proc newImageFromDataString(data: string; width, height: int): Image =
    new(result)
    result.grids = newSeq[Grid](4)
    result.format = "RGBA"
    result.grids[0] = newGrid(width, height)
    result.grids[1] = newGrid(width, height)
    result.grids[2] = newGrid(width, height)
    result.grids[3] = newGrid(width, height)
    result.width = width
    result.height = height
    var i = 0; var j = 0
    for row in 0..<result.height:
        for col in 0..<result.width:
            result.grids[0].data[j] = float(data[i + 3]) / 255
            result.grids[1].data[j] = float(data[i + 0]) / 255
            result.grids[2].data[j] = float(data[i + 1]) / 255
            result.grids[3].data[j] = float(data[i + 2]) / 255
            i += 4
            inc j

proc newDataStringFromImage(img: Image): string =
    result = newString(img.width * img.height * 4)
    var i = 0; var j = 0
    for row in 0..<img.height:
        for col in 0..<img.width:
            result[i + 0] = char((img.grids[0].data[j] * 255).clamp(0, 255))
            result[i + 1] = char((img.grids[1].data[j] * 255).clamp(0, 255))
            result[i + 2] = char((img.grids[2].data[j] * 255).clamp(0, 255))
            result[i + 3] = char((img.grids[3].data[j] * 255).clamp(0, 255))
            i += 4
            inc j

proc newImageFromCanvas(c: Canvas): Image = newImageFromDataString(c.data, c.width, c.height)

proc savePNG(img: Image, filename: string): void =
    let data = newDataStringFromImage(img)
    discard savePNG(filename, data, LCT_RGBA, 8, img.width, img.height)
    
let
    canvas = newCanvas(320, 320)
    cr = canvas.context
cr.scale(320, 320)
cr.set_line_width(0.005)
cr.move_to(0.6, 0)
cr.line_to(0.4, 1)
cr.set_source_rgba(1.0, 0.0, 0.0, 0.5)
cr.stroke

let
    img = newImageFromCanvas(canvas)
    island = genIsland(9, 320)

img.grids[0] += island * 2
img.grids[1] += island * 2
img.grids[2] += island * 2
img.grids[3] += island

img.savePNG("big.png")
