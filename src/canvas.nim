import cairo
import image

type
    Canvas* = ref object
        data*: string
        width*, height*: int
        surface: PSurface
        context: PContext

proc newCanvas*(width, height: int): Canvas =
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
    result.context.scale float64(width), float64(width)
    result.context.setLineWidth(0.005)

proc toImage*(c: Canvas): Image = newImageFromDataString(c.data, c.width, c.height)
proc scale*(c: Canvas; x, y: float): void = c.context.scale(x, y)
proc setLineWidth*(c: Canvas; width: float): void = c.context.set_line_width(width)
proc moveTo*(c: Canvas; x, y: float): void = c.context.move_to(x, y)
proc lineTo*(c: Canvas; x, y: float): void = c.context.line_to(x, y)
proc setColor*(c: Canvas; red, grn, blu, alp: float): void =
    c.context.setSourceRgba(red, grn, blu, alp)
proc stroke*(c: Canvas): void = c.context.stroke
