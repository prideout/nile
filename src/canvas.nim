import cairo
import image
import math
import vector

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

proc scale*(c: Canvas; x, y: float): auto =
    c.context.scale(x, y); c

proc setLineWidth*(c: Canvas; width: float): auto =
    c.context.set_line_width(width); c

proc setColor*(c: Canvas; red, grn, blu, alp: float): auto =
    c.context.setSourceRgba(red, grn, blu, alp); c

proc stroke*(c: Canvas): auto {.discardable.} =
    c.context.stroke; c

proc fill*(c: Canvas): auto {.discardable.} =
    c.context.fill; c

proc moveTo*(c: Canvas; pt: Vec2f): auto =
    c.context.move_to(pt.x, pt.y); c

proc lineTo*(c: Canvas; pt: Vec2f): auto =
    c.context.line_to(pt.x, pt.y); c

proc circle*(c: Canvas; pt: Vec2f, radius: float): auto =
    let ctx = c.context; ctx.save()
    ctx.translate(pt.x, pt.y)
    ctx.scale(radius, radius)
    ctx.arc(0, 0, 1, 0, 2 * PI)
    ctx.restore(); c
