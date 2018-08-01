import math
import sequtils
import strutils

import private/utils

let FilterHermite* = Filter(radius: 1, function: proc (x: float32): float32 =
    if x >= 1.0: return 0
    2 * x * x * x - 3 * x * x + 1)

let FilterTriangle* = Filter(radius: 1, function: proc (x: float32): float32 =
    if x >= 1.0: return 0
    1.0 - x)

let FilterGaussian* = Filter(radius: 2, function: proc (x: float32): float32 =
    const scale = 1.0f / sqrt(0.5f * math.PI)
    if x >= 2.0: return 0
    exp(-2 * x * x) * scale)

## Simple two-dimensional image with floating-point luminance data.
## Values are stored in row-major (scanline) order, but coordinates and dimensions use
## X Y notation (i.e. columns ⨯ rows) with 0,0 being the top-left.
type
    Grid* = ref object
      data*: seq[float32]
      width*, height*: int

# Creates a grid full of zeros.
proc newGrid*(width, height: int): Grid =
    new(result)
    result.data = newSeq[float32](width * height)
    result.width = width
    result.height = height

# Creates a grid filled with the given value.
proc newGrid*(width, height: int, value: float32): Grid =
    new(result)
    result.data = repeat(value, width * height)
    result.width = width
    result.height = height

# Clone a grid.
proc newGrid*(grid: Grid): Grid =
    new(result)
    result.data = grid.data
    result.width = grid.width
    result.height = grid.height

# Consumes a multiline string composed of 0's and 1's.
proc newGrid*(pattern: string): Grid =
    new(result)
    for iter in tokenize(pattern):
        if not iter.isSep:
            inc result.height
            let ncols = iter.token.len()
            if result.width == 0:
                result.width = ncols
            elif result.width != ncols: 
                doAssert false
    result.data = newSeq[float32](result.width * result.height)
    var n = 0
    for iter in tokenize(pattern):
        if not iter.isSep:
            for c in iter.token:
                result.data[n] = float32(ord(c) - ord('0'))
                inc n

# Returns a new grid with the results of op applied to every value.
proc map*(g: Grid, op: proc (x: float32): float32): Grid =
    new(result)
    result.data = map(g.data, op)
    result.width = g.width
    result.height = g.height

# Convenience template around the map proc to reduce typing.
template mapIt*(g: Grid, op: untyped): Grid =
    new(result)
    result.data = newSeq[float32](g.data.len)
    result.width = g.width
    result.height = g.height
    var i = 0
    let t = g.data
    for it {.inject.} in t:
        result.data[i] = op
        inc i
    result

# Applies op to every item in g modifying it directly.
proc apply*(g:Grid, op: proc (x: var float32): void): void = g.data.apply(op)

# Addition.
proc `+`*(k: float32, g: Grid): Grid = g.map(proc(f: float32): float32 = k + f)
proc `+`*(g: Grid, k: float32): Grid = k + g    
proc `+=`*(g: Grid, k: float32): void = g.apply(proc(f: var float32): void = f += k)
proc `+=`*(a: Grid, b: Grid): void =
    assert(a.data.len() == b.data.len())
    for i in 0..<a.data.len(): a.data[i] += b.data[i]

# Multiplication (component wise).
proc `*`*(g: Grid, k: float32): Grid = g.map(proc(f: float32): float32 = f * k)
proc `*`*(k: float32, g: Grid): Grid = g.map(proc(f: float32): float32 = f * k)
proc `*=`*(g: Grid, k: float32): void = g.apply(proc(f: var float32): void = f *= k)
proc `*=`*(a: Grid, b: Grid): void =
    assert(a.data.len() == b.data.len())
    for i in 0..<a.data.len(): a.data[i] *= b.data[i]

# Misc other math ops.
proc `/`*(g: Grid, k: float32): Grid = g * (1.0f / k)
proc `/=`*(g: Grid, k: float32): void = g *= (1.0f / k)    
proc `-`*(k: float32, g: Grid): Grid = g.map(proc(f: float32): float32 = k - f)
proc `-`*(g: Grid, k: float32): Grid = g + (-k)
proc `-=`*(g: Grid, k: float32): void = g.apply(proc(f: var float32): void = f += k)

# Do not use zip in the following procs, it seems inefficient.
proc `+`*(a: Grid, b: Grid): Grid =
    assert(a.width == b.width and a.height == b.height)
    new(result)
    result.data = newSeq[float32](a.data.len())
    for i in 0..<a.data.len(): result.data[i] = a.data[i] + b.data[i]
    result.width = a.width
    result.height = a.height

proc `-`*(a: Grid, b: Grid): Grid =
    assert(a.width == b.width and a.height == b.height)
    new(result)
    result.data = newSeq[float32](a.data.len())
    for i in 0..<a.data.len(): result.data[i] = a.data[i] - b.data[i]
    result.width = a.width
    result.height = a.height

proc `*`*(a: Grid, b: Grid): Grid =
    assert(a.width == b.width and a.height == b.height)
    new(result)
    result.data = newSeq[float32](a.data.len())
    for i in 0..<a.data.len(): result.data[i] = a.data[i] * b.data[i]
    result.width = a.width
    result.height = a.height

proc step*(g: Grid, k: float32): Grid = g.map(proc(f: float32): float32 =
    if f <= k: 0 else: 1)

# Finds the smallest value in the entire grid.
proc min*(g: Grid): float32 = foldl(g.data, min(a, b), high(float32))

# Finds the largest value in the entire grid.
proc max*(g: Grid): float32 = foldl(g.data, max(a, b), low(float32))

# Sets the pixel value at the given column and row.
proc setPixel*(g: Grid, x, y: int, k: float32 = 1): void =
    assert(x >= 0 and x < g.width and y >= 0 and y < g.height)
    g.data[y * g.width + x] = k

# Adds the given value into the texel
proc addPixel*(g: Grid, x, y: int, k: float32 = 1): void =
    assert(x >= 0 and x < g.width and y >= 0 and y < g.height)
    g.data[y * g.width + x] += k
    
# Gets the pixel value at the given column and row.
proc getPixel*(g: Grid, x, y: int): float32 =
    assert(x >= 0 and x < g.width and y >= 0 and y < g.height)
    g.data[y * g.width + x]

# Takes floating point coordinates in [0,+1] and returns the nearest pixel value.
proc sampleNearest*(g: Grid, x, y: float32): float32 =
    let col = max(0, min(int(float32(g.width) * x), g.width - 1))
    let row = max(0, min(int(float32(g.height) * y), g.height - 1))
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
proc drawGrid*(g: Grid; ncols, nrows: int; value: float32 = 0): Grid =
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
proc computeAverage*(g: Grid; left, top, right, bottom: float32): float32 =
    let
        x0 = left * float32(g.width)
        y0 = top * float32(g.height)
        x1 = right * float32(g.width)
        y1 = bottom * float32(g.height)
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
        w = float32(inner_col0) - x0
        e = x1 - float32(outer_col1)
        n = float32(inner_row0) - y0
        s = y1 - float32(outer_row1)
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
    let dx = 1.0f / float32(width)
    let dy = 1.0f / float32(height)
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
    let dx = 1.0f / float32(width)
    let dy = 1.0f / float32(height)
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
    var transpose = newSeq[float32](source.height)
    for tx in 0..<width:
        for y in 0..<source.height:
            transpose[y] = horizontal.getPixel(tx, y)
        for ty, sy, weight in ops.items():
            result.addPixel(tx, ty, transpose[sy] * weight)

# Create an image from a rectangular region.
proc crop*(source: Grid, left, top, right, bottom: int): Grid =
    result = newGrid(right - left, bottom - top)
    var i = 0
    for row in 0..<result.height:
        for col in 0..<result.width:
            result.data[i] = source.getPixel(left + col, top + row)
            inc i

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

type Viewport* = tuple[left, top, right, bottom: float32]

# Creates a scalar field with C1 continuity whose values are roughly in [-0.8, +0.8]
# The viewport that spans from [-1,-1] to [+1,+1] is a 2x2 grid of surflets.
proc generateGradientNoise*(seed: int; width, height: int; viewport: Viewport): Grid =
    result = newGrid(width, height)
    let
        table = newGradientNoiseTable(seed)
        vpwidth = viewport.right - viewport.left
        vpheight = viewport.bottom - viewport.top
        dx = vpwidth / float32(width)
        sx = viewport.left + dx / 2
        dy = vpheight / float32(height)
        sy = viewport.top + dy / 2
    var i = 0
    for row in 0..<height:
        let y = sy - float32(row) * dy
        for col in 0..<width:
            let x = sx + float32(col) * dx
            result.data[i] = table.computeNoiseValue(x, y)
            inc i

# Creates a scalar field with C1 continuity whose values are roughly in [-0.8, +0.8]
# Frequency of 1.0 corresponds to a 2x2 grid of surflets.
proc generateGradientNoise*(seed: int; width, height: int; frequency: float32): Grid =
    # TODO: pay attention to aspect ratio
    let f = frequency
    let viewport = (-f, -f, f, f)
    generateGradientNoise(seed, width, height, viewport)

# Exports the floating-point data by clamping to [0, 1] and scaling to 255.
proc toDataString*(g: Grid): string =
    let npixels = g.width * g.height
    result = newString(npixels)
    for i in 0..<npixels:
        let v = g.data[i].clamp(0, 1)
        result[i] = chr(int(v * 255))
