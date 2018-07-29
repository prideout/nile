import math

type Filter* = object
    radius*: float
    function*: proc (x: float): float

# Regardless of filter type, any resizing operation executes a Multiply-Accumulate (Macc) more
# than anything else. This can be described as:
#       targetRow[targetColumn] += sourceRow[sourceColumn] * filterWeight
# The operands that can be cached from row to row are the two indices and the weight.
type MaccOp = tuple[targetColumn: int, sourceColumn: int, filterWeight: float]

# Generates a list of MACC instructions that results in the transformation of a sequence of length
# "sourceLen" into a sequence of length "targetLen" using the specified filter function.
proc computeMaccOps*(targetLen, sourceLen: int; filter: Filter): seq[MaccOp] =
    result = newSeq[MaccOp]()
    let
        targetDelta = 1 / float(targetLen)
        sourceDelta = 1 / float(sourceLen)
    var x = targetDelta / 2
    for targetIndex in 0..<targetLen:
        let
            minx = x - filter.radius * sourceDelta
            maxx = x + filter.radius * sourceDelta
            minsi = int(minx * float(sourceLen))
            maxsi = int(ceil(maxx * float(sourceLen)))
        var
            nsamples = 0
            weightSum = 0.0f
        for si in minsi..maxsi:
            if si < 0 or si >= sourceLen: continue
            let
                sx = (0.5 + float(si)) * sourceDelta
                t = float(sourceLen) * abs(sx - x)
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
