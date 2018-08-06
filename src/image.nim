import grid
import strformat
import vector

type
    Image* = ref object
        width*, height*: int
        red*: Grid
        grn*: Grid
        blu*: Grid
        alp*: Grid
    ColorGradient* = ref object
        red*: array[256, float32]
        grn*: array[256, float32]
        blu*: array[256, float32]
        alp*: array[256, float32]

proc addOverlay*(a, b: Image): Image =
    new(result)
    assert(a.width == b.width and a.height == b.height)
    let invalp = 1 - b.alp
    result.red = a.red * invalp
    result.grn = a.grn * invalp
    result.blu = a.blu * invalp
    result.alp = a.alp * invalp
    result.red += b.red
    result.grn += b.grn
    result.blu += b.blu
    result.alp += b.alp
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

# Given 0xRRGGBB, returns a 3-tuple in [0,1]
proc colorToFloat3(color: int): Vec3f =
    let
        red = float32((color shr 16) and 0xff)
        grn = float32((color shr 08) and 0xff)
        blu = float32((color shr 00) and 0xff)
    (red / 255.0f, grn / 255.0f, blu / 255.0f)

# TODO: linearize, then delinearize; see
# https://github.com/prideout/heman/blob/master/src/color.c
proc newColorGradient*(colors: seq[int]): ColorGradient =
    new(result)
    assert (colors.len() mod 2) == 0
    assert colors.len() > 2
    assert colors[0] == 0
    assert colors[colors.len() - 2] == 255
    var i = 0
    while i < colors.len() - 2:
        let
            currval = colors[i]
            nextval = colors[i + 2]
            currrgb = colorToFloat3(colors[i + 1])
            nextrgb = colorToFloat3(colors[i + 3])
        assert(currval >= 0 and currval < 256)
        assert(nextval >= 0 and nextval < 256)
        assert(nextval >= currval)
        let
            ncols = nextval - currval
            del = (nextrgb - currrgb) / float(ncols)
        var col = currrgb
        for j in currval..nextval:
            result.red[j] = col.x
            result.grn[j] = col.y
            result.blu[j] = col.z
            col += del
        i += 2

proc applyColorGradient*(image: Image, colors: ColorGradient): void =
    var j = 0
    for row in 0..<image.height:
        for col in 0..<image.width:
            let
                red = (image.red.data[j] * 255).clamp(0, 255)
                grn = (image.grn.data[j] * 255).clamp(0, 255)
                blu = (image.blu.data[j] * 255).clamp(0, 255)
            image.red.data[j] = colors.red[int(red)]
            image.grn.data[j] = colors.grn[int(grn)]
            image.blu.data[j] = colors.blu[int(blu)]
            inc j
