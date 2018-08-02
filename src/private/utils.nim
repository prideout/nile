import hashes
import math
import random
import ../vector

type Filter* = object
    radius*: float32
    function*: proc (x: float32): float32

# Regardless of filter type, any resizing operation executes a Multiply-Accumulate (Macc) more
# than anything else. This can be described as:
#       targetRow[targetColumn] += sourceRow[sourceColumn] * filterWeight
# The operands that can be cached from row to row are the two indices and the weight.
type MaccOp = tuple[targetColumn: int, sourceColumn: int, filterWeight: float32]

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

# Generates a list of MACC instructions that results in the transformation of a sequence of length
# "sourceLen" into a sequence of length "targetLen" using the specified filter function.
proc computeMaccOps*(targetLen, sourceLen: int; filter: Filter): seq[MaccOp] =
    result = newSeq[MaccOp]()
    let
        targetDelta = 1 / float32(targetLen)
        sourceDelta = 1 / float32(sourceLen)
        minifying = targetLen < sourceLen
        filterExtent = if minifying: targetDelta else: sourceDelta
        filterDomain = float32(if minifying: targetLen else: sourceLen)
    var x = targetDelta / 2
    for targetIndex in 0..<targetLen:
        let
            minx = x - filter.radius * filterExtent
            maxx = x + filter.radius * filterExtent
            minsi = int(minx * float32(sourceLen))
            maxsi = int(ceil(maxx * float32(sourceLen)))
        var
            nsamples = 0
            weightSum = 0.0f
        for si in minsi..maxsi:
            if si < 0 or si >= sourceLen: continue
            let
                sx = (0.5 + float32(si)) * sourceDelta
                t = filterDomain * abs(sx - x)
                weight = filter.function(t)
            if weight != 0:
                result.add (targetIndex, si, weight)
                weightSum += weight
                inc nsamples
        if weightSum > 0:
            while nsamples > 0:
                result[result.len() - nsamples].filterWeight /= weightSum
                dec nsamples
        x += targetDelta
