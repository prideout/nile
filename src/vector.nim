type
    Vec2f* = tuple[x, y: float32]
    Vec2i* = tuple[x, y: int32]

proc `*`*(a: Vec2f, b: Vec2f): Vec2f = (a.x * b.x, a.y * b.y)
proc `*`*(a: Vec2f, b: float32): Vec2f = (a.x * b, a.y * b)
proc `+`*(a: Vec2f, b: float32): Vec2f = (a.x + b, a.y + b)
proc `-`*(a: Vec2f, b: float32): Vec2f = (a.x - b, a.y - b)
proc `+`*(a: Vec2f, b: Vec2f): Vec2f = (a.x + b.x, a.y + b.y)
proc `-`*(a: Vec2f, b: Vec2f): Vec2f = (a.x - b.x, a.y - b.y)
proc dot*(a: Vec2f, b: Vec2f): float32 = a.x * b.x + a.y * b.y
proc `+`*(a: Vec2i, b: int32): Vec2i = (a.x + b, a.y + b)
proc `-`*(a: Vec2i, b: int32): Vec2i = (a.x - b, a.y - b)
proc `+`*(a: Vec2i, b: Vec2i): Vec2i = (a.x + b.x, a.y + b.y)
proc `-`*(a: Vec2i, b: Vec2i): Vec2i = (a.x - b.y, a.y - b.y)
