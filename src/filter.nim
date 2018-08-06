import math
import image
import grid

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

proc resize*(image: Image, width, height: int, filter: Filter): void =
    image.width = width
    image.height = height
    image.red = image.red.resize(width, height, filter)
    image.grn = image.grn.resize(width, height, filter)
    image.blu = image.blu.resize(width, height, filter)
    image.alp = image.alp.resize(width, height, filter)
