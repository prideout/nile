#!/usr/bin/env nim c --debugger:native --run

#!/usr/bin/env nim c -d:release --boundChecks:off --run

import nimPNG
import sequtils
import strutils
import strformat
import math

const check = true

type Filter = object
    radius: float
    function: proc (x: float): float

let FilterHermite* = Filter(radius: 1, function: proc (x: float): float =
    if x >= 1.0: return 0
    2 * x * x * x - 3 * x * x + 1)

let FilterTriangle* = Filter(radius: 1, function: proc (x: float): float =
    if x >= 1.0: return 0
    1.0 - x)

let FilterGaussian* = Filter(radius: 2, function: proc (x: float): float =
    const scale = 1.0f / sqrt(0.5f * math.PI)
    if x >= 2.0: return 0
    exp(-2 * x * x) * scale)

# https://github.com/stavenko/nim-glm
# https://github.com/unicredit/neo
# http://entropymine.com/imageworsener/pixelmixing/

## Simple two-dimensional image with floating-point luminance data.
## Values are stored in row-major (scanline) order, but coordinates and dimensions use
## X Y notation (i.e. columns ⨯ rows) with 0,0 being the top-left.
type
    Grid = ref object
      data: seq[float]
      width, height: int

# Creates a grid full of zeros.
proc newGrid(width, height: int): Grid =
    new(result)
    result.data = newSeq[float](width * height)
    result.width = width
    result.height = height

# Consumes a multiline string composed of 0's and 1's.
proc newGrid(pattern: string): Grid =
    new(result)
    for iter in tokenize(pattern):
        if not iter.isSep:
            inc result.height
            let ncols = iter.token.len()
            if result.width == 0:
                result.width = ncols
            elif result.width != ncols: 
                doAssert false
    result.data = newSeq[float](result.width * result.height)
    var n = 0
    for iter in tokenize(pattern):
        if not iter.isSep:
            for c in iter.token:
                result.data[n] = float(ord(c) - ord('0'))
                inc n

# Returns a new grid with the results of op applied to every value.
proc map*(g:Grid, op: proc (x: float): float): Grid =
    new(result)
    result.data = map(g.data, op)
    result.width = g.width
    result.height = g.height

# Applies op to every item in g modifying it directly.
proc apply*(g:Grid, op: proc (x: var float): void): void = g.data.apply(op)

# Math operators.
proc `*`*(g: Grid, k: float): Grid = g.map(proc(f: float): float = f * k)
proc `*`*(k: float, g: Grid): Grid = g.map(proc(f: float): float = f * k)
proc `*=`*(g: Grid, k: float): void = g.apply(proc(f: var float): void = f *= k)
proc `/`*(g: Grid, k: float): Grid = g * (1.0f / k)
proc `/=`*(g: Grid, k: float): void = g *= (1.0f / k)    
proc `+`*(k: float, g: Grid): Grid = g.map(proc(f: float): float = k + f)
proc `-`*(k: float, g: Grid): Grid = g.map(proc(f: float): float = k - f)
proc `+`*(g: Grid, k: float): Grid = k + g
proc `-`*(g: Grid, k: float): Grid = g + (-k)
proc `+=`*(g: Grid, k: float): void = g.apply(proc(f: var float): void = f += k)
proc `-=`*(g: Grid, k: float): void = g.apply(proc(f: var float): void = f += k)

# Finds the smallest value in the entire grid.
proc min*(g: Grid): float = foldl(g.data, min(a, b), high(float))

# Finds the largest value in the entire grid.
proc max*(g: Grid): float = foldl(g.data, max(a, b), low(float))

# Sets the pixel value at the given column and row.
proc setPixel*(g: Grid, x, y: int, k: float = 1): void =
    if check:
        doAssert(x >= 0 and x < g.width)
        doAssert(y >= 0 and y < g.height)
    g.data[y * g.width + x] = k

# Adds the given value into the texel
proc addPixel*(g: Grid, x, y: int, k: float = 1): void =
    if check:
        doAssert(x >= 0 and x < g.width)
        doAssert(y >= 0 and y < g.height)
    g.data[y * g.width + x] += k
    
# Gets the pixel value at the given column and row.
proc getPixel*(g: Grid, x, y: int): float =
    if check:
        doAssert(x >= 0 and x < g.width)
        doAssert(y >= 0 and y < g.height)
    g.data[y * g.width + x]

# Takes floating point coordinates in [0,+1] and returns the nearest pixel value.
proc sampleNearest(g: Grid, x, y: float): float =
    let col = max(0, min(int(float(g.width) * x), g.width - 1))
    let row = max(0, min(int(float(g.height) * y), g.height - 1))
    g.data[row * g.width + col]

# Copies a region of pixels from the source grid.
proc blitFrom*(dst: Grid, src: Grid; dstx, dsty: int; left, top, right, bottom: int): void =
    var dstrow = dsty;
    for srcrow in top..<bottom:
        var dstcol = dstx;
        for srccol in left..<right:
            dst.setPixel(dstcol, dstrow, src.getPixel(srccol, srcrow))
            inc dstcol
        inc dstrow

# Draws single-pixel gridlines such that "ncols ⨯ nrows" cells have borders.
# Increases the width and height of the grid by 1 pixel.
proc drawGrid*(g: Grid; ncols, nrows: int; value: float = 0): Grid =
    result = newGrid(g.width + 1, g.height + 1)
    result.blitFrom(g, 0, 0, 0, 0, g.width, g.height)
    for row in 0..<nrows:
        let y = int(row * g.height / nrows)
        for x in 0..<g.width:
            result.setPixel(x, y, value)
    for col in 0..<ncols:
        let x = int(col * g.width / ncols)
        for y in 0..<g.height:
            result.setPixel(x, y, value)
    if value != 0:
        let y = result.height - 1
        for x in 0..<result.width:
            result.setPixel(x, y, value)
        let x = result.width - 1
        for y in 0..<result.height:
            result.setPixel(x, y, value)
    
# Computes an average value over a viewport in [0,+1] and accounts for pixel squares that are
# only partially covered by the viewport.
proc computeAverage*(g: Grid; left, top, right, bottom: float): float =
    let
        x0 = left * float(g.width)
        y0 = top * float(g.height)
        x1 = right * float(g.width)
        y1 = bottom * float(g.height)
        inner_col0 = int(ceil(x0)).max(0)
        inner_row0 = int(ceil(y0)).max(0)
        inner_col1 = int(floor(x1)).min(g.width) - 1
        inner_row1 = int(floor(y1)).min(g.height) - 1
        outer_col0 = int(floor(x0)).max(0)
        outer_row0 = int(floor(y0)).max(0)
        outer_col1 = int(ceil(x1)).min(g.width) - 1
        outer_row1 = int(ceil(y1)).min(g.height) - 1
    var
        area = 0.0f
        total = 0.0f
    # First add up the pixel squares that lie completely inside the viewport.
    for col in inner_col0..inner_col1:
        for row in inner_row0..inner_row1:
            area += 1.0
            total += g.getPixel(col, row)
    # Determine the amount of fractional overhang on all 4 sides.
    let
        w = float(inner_col0) - x0
        e = x1 - float(outer_col1)
        n = float(inner_row0) - y0
        s = y1 - float(outer_row1)
    # Left column of pixels with fractional coverage.
    if w > 0:
        for row in inner_row0..inner_row1:
            area += w; total += w * g.getPixel(outer_col0, row)
    # Right column of pixels with fractional coverage.
    if e > 0:
        for row in inner_row0..inner_row1:
            area += e; total += e * g.getPixel(outer_col1, row)
    # Top row of pixels with fractional coverage.
    if n > 0:
        for col in inner_col0..inner_col1:
            area += n; total += n * g.getPixel(col, outer_row0)
    # Bottom row of pixels with fractional coverage.
    if s > 0:
        for col in inner_col0..inner_col1:
            area += s; total += s * g.getPixel(col, outer_row1)
    # Northwest corner.
    if w > 0 and n > 0:
        area += w * n; total += w * n * g.getPixel(outer_col0, outer_row0)
    # Southwest corner.
    if w > 0 and s > 0:
        area += w * s; total += w * s * g.getPixel(outer_col0, outer_row1)
    # Northeast corner.
    if e > 0 and n > 0:
        area += e * n; total += e * n * g.getPixel(outer_col1, outer_row0)
    # Southeast corner.
    if s > 0 and e > 0:
        area += s * e; total += s * e * g.getPixel(outer_col1, outer_row1)
    total / area

# Resamples the given image using a technique sometimes called "pixel mixing".
# This is the same as a classic box filter when magnifying or minifying by a multiple of 2.
proc resizeBoxFilter*(g: Grid, width, height: int): Grid =
    result = newGrid(width, height)
    let dx = 1.0f / float(width)
    let dy = 1.0f / float(height)
    var x = 0.0f
    var y = 0.0f
    var i = 0
    for row in 0..<height:
        x = 0
        for col in 0..<width:
            let v = g.computeAverage(x, y, x + dx, y + dy)
            result.data[i] = v
            inc i
            x += dx
        y += dy

# Resizes an image by choosing nearest pixels from the source image (does no filtering whatsoever).
proc resizeNearestFilter*(g: Grid, width, height: int): Grid =
    result = newGrid(width, height)
    let dx = 1.0f / float(width)
    let dy = 1.0f / float(height)
    var x = 0.5f * dx
    var y = 0.5f * dy
    var i = 0
    for row in 0..<height:
        x = 0
        for col in 0..<width:
            result.data[i] = g.sampleNearest(x, y)
            inc i
            x += dx
        y += dy

# Resizes an image by choosing nearest pixels from the source image (does no filtering whatsoever).
proc resizeNearestFilter*(g: Grid, scale: int): Grid =
    g.resizeNearestFilter(g.width * scale, g.height * scale)

# Regardless of filter type, any resizing operation executes a Multiply-Accumulate (Macc) more
# than anything else. This can be described as:
#       targetRow[targetColumn] += sourceRow[sourceColumn] * filterWeight
# The operands that can be cached from row to row are the two indices and the weight.
type MaccOp = tuple[targetColumn: int, sourceColumn: int, filterWeight: float]

# Generates a list of MACC instructions that results in the transformation of a sequence of length
# "sourceLen" into a sequence of length "targetLen" using the specified filter function.
proc computeMaccOps(targetLen, sourceLen: int; filter: Filter): seq[MaccOp] =
    result = newSeq[MaccOp]()
    let
        targetDelta = 1 / float(targetLen)
        sourceDelta = 1 / float(sourceLen)
    var x = targetDelta / 2
    for targetIndex in 0..<targetLen:
        let
            minx = x - filter.radius * sourceDelta
            maxx = x + filter.radius * sourceDelta
            minsi = int(minx * float(sourceLen))
            maxsi = int(ceil(maxx * float(sourceLen)))
        var
            nsamples = 0
            weightSum = 0.0f
        for si in minsi..maxsi:
            if si < 0 or si >= sourceLen: continue
            let
                sx = (0.5 + float(si)) * sourceDelta
                t = float(sourceLen) * abs(sx - x)
                weight = filter.function(t)
            if weight != 0:
                result.add (targetIndex, si, weight)
                weightSum += weight
                inc nsamples
        if weightSum > 0:
            while nsamples > 0:
                result[result.len() - nsamples].filterWeight /= weightSum
                dec nsamples
        x += targetDelta

# Resizes an image with the given filter.
proc resize*(source: Grid, width, height: int, filter: Filter): Grid =
    # First resize horizontally.
    let horizontal = newGrid(width, source.height)
    var ops = computeMaccOps(width, source.width, filter)
    for ty in 0..<horizontal.height:
        for tx, sx, weight in ops.items():
            horizontal.addPixel(tx, ty, source.getPixel(sx, ty) * weight)
    # Next resize vertically.
    result = newGrid(width, height)
    ops = computeMaccOps(height, source.height, filter)
    var transpose = newSeq[float](source.height)
    for tx in 0..<width:
        for y in 0..<source.height:
            transpose[y] = horizontal.getPixel(tx, y)
        for ty, sy, weight in ops.items():
            result.addPixel(tx, ty, transpose[sy] * weight)

# Stacks arrays horizontally (column wise).
proc hstack*(a: Grid, b: varargs[Grid]): Grid =
    var width = a.width
    for g in items(b):
        width += g.width
    result = newGrid(width, a.height)
    for row in 0..<result.height:
        for col in 0..<a.width:
            result.setPixel(col, row, a.getPixel(col, row))
    for row in 0..<result.height:
        var tcol = a.width
        for g in items(b):
            doAssert(a.height == g.height)
            for scol in 0..<g.width:
                result.setPixel(tcol, row, g.getPixel(scol, row))
                inc tcol

# Stacks arrays vertically (row wise).
proc vstack*(a: Grid, b: varargs[Grid]): Grid =
    var height = a.height
    for g in items(b):
        height += g.height
    result = newGrid(a.width, height)
    for col in 0..<result.width:
        for row in 0..<a.height:
            result.setPixel(col, row, a.getPixel(col, row))
    for col in 0..<result.width:
        var trow = a.height
        for g in items(b):
            doAssert(a.width == g.width)
            for srow in 0..<g.height:
                result.setPixel(col, trow, g.getPixel(col, srow))
                inc trow

# Exports the floating-point data by clamping to [0, 1] and scaling to 255.
proc savePNG(g: Grid, filename: string): void =
    let npixels = g.width * g.height
    var u8data = newString(npixels)
    for i in 0..<npixels:
        u8data[i] = chr(int(g.data[i] * 255))
    discard savePNG(filename, u8data, LCT_GREY, 8, g.width, g.height)

if isMainModule:
    const diagramScale = 16

    let original = 1 - newGrid("""
        00000000
        00111100
        00100100
        00111100
        00100000
        00100000
        00100000
        00000000""")
    original.setPixel(7, 7, 0.5)
    var mag = original.resizeBoxFilter(11, 11).resizeNearestFilter(diagramScale).drawGrid(11, 11)
    var ide = original.resizeBoxFilter(8, 8).resizeNearestFilter(diagramScale).drawGrid(8, 8)
    var min = original.resizeBoxFilter(5, 5).resizeNearestFilter(diagramScale).drawGrid(5, 5)
    min.savePNG("min0.png")
    mag.savePNG("mag0.png")
    ide.savePNG("ide0.png")

    let tiny = newGrid("000 010 000")
    min = tiny.resizeBoxFilter(1, 1).resizeNearestFilter(diagramScale).drawGrid(1, 1)
    mag = tiny.resizeBoxFilter(5, 5).resizeNearestFilter(diagramScale).drawGrid(5, 5)
    ide = tiny.resizeBoxFilter(9, 9).resizeNearestFilter(diagramScale).drawGrid(9, 9)
    min.savePNG("min1.png")
    mag.savePNG("mag1.png")
    ide.savePNG("ide1.png")

    let row = newGrid("010")
    mag = row.resize(5, 1, FilterHermite).resizeNearestFilter(diagramScale).drawGrid(5, 1, 1)
    mag.savePNG("mag2.png")
    mag = tiny.resize(5, 5, FilterHermite).resizeNearestFilter(diagramScale).drawGrid(5, 5, 1)
    mag.savePNG("mag3.png")
    mag = tiny.resize(128, 128, FilterHermite).drawGrid(1, 1, 1)
    mag.savePNG("mag4.png")

    let nearest = original.resizeNearestFilter(1000, 1000).resizeBoxFilter(100, 100)
    let hermite = original.resize(1000, 1000, FilterHermite).resizeBoxFilter(100, 100)
    let gauss = original.resize(1000, 1000, FilterGaussian).resizeBoxFilter(100, 100)
    let triangle = original.resize(1000, 1000, FilterTriangle).resizeBoxFilter(100, 100)
    (1 - hstack(nearest, hermite, gauss, triangle)).drawGrid(4, 1, 1).savePNG("min2.png")
    (0.2 + 0.5 * vstack(nearest, hermite, gauss, triangle)).drawGrid(1, 4, 1).savePNG("min3.png")
