import math

type
    Vec2f* = tuple[x, y: float32]
    Vec2i* = tuple[x, y: int32]
    Viewport* = tuple[left, top, right, bottom: float32]

const ENTIRE* = (0.0f, 0.0f, 1.0f, 1.0f)

proc `*`*(a: Vec2f, b: Vec2f): Vec2f = (a.x * b.x, a.y * b.y)
proc `*`*(a: Vec2f, b: float32): Vec2f = (a.x * b, a.y * b)
proc `*`*(a: float32, b: Vec2f): Vec2f = (a * b.x, a * b.y)
proc `/`*(a: Vec2f, b: float32): Vec2f = (a.x / b, a.y / b)
proc `+`*(a: Vec2f, b: float32): Vec2f = (a.x + b, a.y + b)
proc `-`*(a: Vec2f, b: float32): Vec2f = (a.x - b, a.y - b)
proc `+`*(a: Vec2f, b: Vec2f): Vec2f = (a.x + b.x, a.y + b.y)
proc `-`*(a: Vec2f, b: Vec2f): Vec2f = (a.x - b.x, a.y - b.y)
proc `+`*(a: Vec2i, b: int32): Vec2i = (a.x + b, a.y + b)
proc `-`*(a: Vec2i, b: int32): Vec2i = (a.x - b, a.y - b)
proc `+`*(a: Vec2i, b: Vec2i): Vec2i = (a.x + b.x, a.y + b.y)
proc `-`*(a: Vec2i, b: Vec2i): Vec2i = (a.x - b.y, a.y - b.y)

proc `+=`*(a: var Vec2f, b: Vec2f): void =
    a.x += b.x
    a.y += b.y

proc dot*(a: Vec2f, b: Vec2f): auto = a.x * b.x + a.y * b.y
proc len*(v: Vec2f): auto = sqrt(dot(v, v))
proc hat*(v: Vec2f): auto = v / v.len()

proc lower*(vp: Viewport): Vec2f = (x: vp.left, y: vp.top)
proc upper*(vp: Viewport): Vec2f = (x: vp.right, y: vp.bottom)
proc center*(vp: Viewport): Vec2f = (vp.lower() + vp.upper()) / 2
proc size*(vp: Viewport): Vec2f = vp.upper() - vp.lower()
proc viewport*(lower, upper: Vec2f): Viewport = (lower.x, lower.y, upper.x, upper.y)
