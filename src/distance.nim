#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

import grid

const INF: float32 = 1e20

type Viewf = object
  data: ptr seq[float32]
  offset: int

type Viewi = object
  data: ptr seq[uint16]
  offset: int

# TODO: instead of get / set, overload `[]` and `[]=`
proc set(sv: var Viewf, i: int, val: float32): void = sv.data[sv.offset + i] = val
proc get(sv: var Viewf, i: int): float32 = sv.data[sv.offset + i]
proc get(g: Grid, x, y: int): float32 = g.data[y * g.width + x]
proc set(g: Grid, x, y: int, v: float32): void = g.data[y * g.width + x] = v

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
    for n in 0..npixels:
        result.data[n] = if result.data[n] == 0: 0.0f else: INF

    echo "Processing Columns..."
    for x in 0..<width:
        var
            f = Viewf(data: addr ff.data, offset: height * x)
            d = Viewf(data: addr dd.data, offset: height * x)
            z = Viewf(data: addr zz.data, offset: (height + 1) * x)
            w = Viewi(data: addr ww, offset: height * x)
        for y in 0..<height:
            f.set(y, result.get(x, y))
        # foo()
        for y in 0..<height:
            result.set(x, y, d.get(y))

    echo "Processing Rows..."
    for y in 0..<height:
        var
            f = Viewf(data: addr ff.data, offset: width * y)
            d = Viewf(data: addr dd.data, offset: width * y)
            z = Viewf(data: addr zz.data, offset: (width + 1) * y)
            w = Viewi(data: addr ww, offset: width * y)
        for x in 0..<width:
            f.set(x, result.get(x, y))
        # foo()
        for x in 0..<width:
            result.set(x, y, d.get(x))

if isMainModule:
    var seq1 = @[1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f]
    var sv = Viewf(data: addr seq1, offset: 2)
    sv.data[1] = 5.0f
    echo sv.data[0]
    echo sv.data[1]
