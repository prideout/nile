import math
import hashes
import random
import grid
import vector

type
    GradientNoiseTable = ref object
        seed: int
        size: int
        mask: int32
        gradients: seq[Vec2f]
        indices: seq[int32]

proc fract(f: float32): float32 = f - floor(f)

proc newGradientNoiseTable*(seed: int): GradientNoiseTable =
    result = new GradientNoiseTable
    result.seed = seed
    result.size = 256
    result.mask = int32(result.size - 1)
    result.gradients = newSeq[Vec2f](result.size)
    result.indices = newSeq[int32](result.size)
    for i in 0..result.mask:
        result.indices[i] = int32(i)
        result.gradients[i].x = cos(float32(i) * 2 * PI / float32(result.size))
        result.gradients[i].y = sin(float32(i) * 2 * PI / float32(result.size))
    var rnd = initRand(seed)
    rnd.shuffle(result.indices)

proc getGradient(table: GradientNoiseTable, p: Vec2i): Vec2f =
    var h: Hash = 0
    h = h !& p.x
    h = h !& p.y
    h = (!$h)
    table.gradients[table.indices[h and table.mask]]

proc computeNoiseValue*(table: GradientNoiseTable, x, y: float32): float32 =
    let
        i = (x: int32(floor(x)), y: int32(floor(y)))
        f = (fract(x), fract(y))
        u = f*f*f*(f*(f*6.0f - 15.0f) + 10.0f)
        ga = table.getGradient(i + (0'i32,0'i32) )
        gb = table.getGradient(i + (1'i32,0'i32) )
        gc = table.getGradient(i + (0'i32,1'i32) )
        gd = table.getGradient(i + (1'i32,1'i32) )
        va = dot(ga, f - (0'f32,0'f32))
        vb = dot(gb, f - (1'f32,0'f32))
        vc = dot(gc, f - (0'f32,1'f32))
        vd = dot(gd, f - (1'f32,1'f32))
    va + u.x * (vb-va) + u.y * (vc-va) + u.x * u.y * (va-vb-vc+vd)

# Creates a scalar field with C1 continuity whose values are roughly in [-0.8, +0.8]
# The viewport that spans from [-1,-1] to [+1,+1] is a 2x2 grid of surflets.
proc generateGradientNoise*(seed: int; width, height: int; viewport: Viewport): Grid =
    result = newGrid(width, height)
    let
        table = newGradientNoiseTable(seed)
        vpwidth = viewport.right - viewport.left
        vpheight = viewport.bottom - viewport.top
        dx = vpwidth / float32(width)
        sx = viewport.left + dx / 2
        dy = vpheight / float32(height)
        sy = viewport.top + dy / 2
    var i = 0
    for row in 0..<height:
        let y = sy - float32(row) * dy
        for col in 0..<width:
            let x = sx + float32(col) * dx
            result.data[i] = table.computeNoiseValue(x, y)
            inc i

# Creates a scalar field with C1 continuity whose values are roughly in [-0.8, +0.8]
# Frequency of 1.0 corresponds to a 2x2 grid of surflets.
proc generateGradientNoise*(seed: int; width, height: int; frequency: float32): Grid =
    # TODO: pay attention to aspect ratio
    let f = frequency
    let viewport = (-f, -f, f, f)
    generateGradientNoise(seed, width, height, viewport)
