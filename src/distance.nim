import grid
import math

const INF: float32 = 1e20

type Viewf = object
  data: ptr seq[float32]
  offset: int

type Viewi = object
  data: ptr seq[uint16]
  offset: int

proc get(g: Grid, x, y: int): float32 = g.data[y * g.width + x]
proc set(g: Grid, x, y: int, v: float32): void = g.data[y * g.width + x] = v
proc `[]=`(sv: Viewi, i: int, val: uint16): void = sv.data[sv.offset + i] = val
proc `[]=`(sv: Viewf, i: int, val: float32): void = sv.data[sv.offset + i] = val
proc `[]`(sv: Viewi, i: int): uint16 = sv.data[sv.offset + i]
proc `[]`(sv: Viewf, i: int): float32 = sv.data[sv.offset + i]
proc `[]`(sv: Viewf, i: uint16): float32 = sv.data[sv.offset + int(i)]
proc sqr(v: float32): float32 = v * v
proc sqr(v: uint16): float32 = float32(v) * float32(v)
proc sqr(v: int): float32 = float32(v * v)

# Low-level function that operates on a single row or column.
proc edt(f, d, z: Viewf, w: Viewi, n: int): void =
    var k: int = 0
    w[0] = 0
    z[0] = -INF
    z[1] = +INF
    for q in 1..<n:
        let q2 = float(q) * 2.0f
        var s = ((f[q] + sqr(q)) - (f[w[k]] + sqr(w[k]))) / (q2 - 2 * float(w[k]))
        while s <= z[k]:
            dec k
            s = ((f[q] + sqr(q)) - (f[w[k]] + sqr(w[k]))) / (q2 - 2 * float(w[k]))
        inc k
        w[k] = uint16(q)
        z[k] = s
        z[k + 1] = +INF
    k = 0
    for q in 0..<n:
        while z[k + 1] < float32(q):
            inc k
        d[q] = sqr(float32(q) - float32(w[k])) + f[w[k]]

proc createEdt*(grid: Grid): Grid =
    new(result)
    var
        width = grid.width
        height = grid.height
        npixels = width * height
        ff = newGrid(width, height)
        dd = newGrid(width, height)
        zz = newGrid(width + 1, height + 1)
        ww = newSeq[uint16](npixels)

    # Create a field of 0 and INF
    result.width = width
    result.height = height
    result.data = newSeq[float32](npixels)
    for n in 0..<npixels:
        result.data[n] = if grid.data[n] <= 0: 0.0f else: INF

    # Process columns
    for x in 0..<width:
        var
            f = Viewf(data: addr ff.data, offset: height * x)
            d = Viewf(data: addr dd.data, offset: height * x)
            z = Viewf(data: addr zz.data, offset: (height + 1) * x)
            w = Viewi(data: addr ww, offset: height * x)
        for y in 0..<height:
            f[y] = result.get(x, y)
        edt(f, d, z, w, height)
        for y in 0..<height:
            result.set(x, y, d[y])

    # Processing rows
    for y in 0..<height:
        var
            f = Viewf(data: addr ff.data, offset: width * y)
            d = Viewf(data: addr dd.data, offset: width * y)
            z = Viewf(data: addr zz.data, offset: (width + 1) * y)
            w = Viewi(data: addr ww, offset: width * y)
        for x in 0..<width:
            f[x] = result.get(x, y)
        edt(f, d, z, w, width)
        for x in 0..<width:
            result.set(x, y, d[x])

    # Post-process by square-rooting and normalizing
    let inv = 1.0 / float32(width)
    for n in 0..<npixels:
        result.data[n] = sqrt(result.data[n]) * inv

proc createSdf*(grid: Grid): Grid =
    var
        width = grid.width
        height = grid.height
        npixels = width * height
        positive = createEdt(grid)
        negative = createEdt(1.0 - grid)
    new(result)
    result.width = grid.width
    result.height = grid.height
    result.data = newSeq[float32](npixels)
    for n in 0..<npixels:
        result.data[n] = positive.data[n] - negative.data[n]
