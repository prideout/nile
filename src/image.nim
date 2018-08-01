import grid

type
    Image* = ref object
        width*, height*: int
        red*: Grid
        grn*: Grid
        blu*: Grid
        alp*: Grid

proc addOverlay*(a, b: Image): Image =
    new(result)
    assert(a.width == b.width and a.height == b.height)
    result.red = a.red * (1 - b.alp) + b.red
    result.grn = a.grn * (1 - b.alp) + b.grn
    result.blu = a.blu * (1 - b.alp) + b.blu
    result.alp = a.alp * (1 - b.alp) + b.alp
    result.width = a.width
    result.height = a.height

proc newImageFromLuminance*(grid: Grid): Image =
    new(result)
    result.red = newGrid(grid)
    result.grn = newGrid(grid)
    result.blu = newGrid(grid)
    result.alp = newGrid(grid.width, grid.height, 1.0f)
    result.width = grid.width
    result.height = grid.height

# TODO: rename to newImageFromBGRA8
proc newImageFromDataString*(data: string; width, height: int): Image =
    new(result)
    result.red = newGrid(width, height)
    result.grn = newGrid(width, height)
    result.blu = newGrid(width, height)
    result.alp = newGrid(width, height)
    result.width = width
    result.height = height
    var i = 0; var j = 0
    for row in 0..<result.height:
        for col in 0..<result.width:
            result.red.data[j] = float(data[i + 2]) / 255
            result.grn.data[j] = float(data[i + 1]) / 255
            result.blu.data[j] = float(data[i + 0]) / 255
            result.alp.data[j] = float(data[i + 3]) / 255
            i += 4
            inc j

# Exports the floating-point data by clamping to [0, 1] and scaling to 255.
# TODO: rename to toRGBA8
proc toDataString*(img: Image): string =
    result = newString(img.width * img.height * 4)
    var i = 0; var j = 0
    for row in 0..<img.height:
        for col in 0..<img.width:
            result[i + 0] = char((img.red.data[j] * 255).clamp(0, 255))
            result[i + 1] = char((img.grn.data[j] * 255).clamp(0, 255))
            result[i + 2] = char((img.blu.data[j] * 255).clamp(0, 255))
            result[i + 3] = char((img.alp.data[j] * 255).clamp(0, 255))
            i += 4
            inc j
