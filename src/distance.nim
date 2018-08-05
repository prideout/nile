import grid

proc createEdt*(grid: Grid): Grid =
    new(result)
    result.width = grid.width
    result.height = grid.height
    result.data = newSeq[float32](grid.width * grid.height)
