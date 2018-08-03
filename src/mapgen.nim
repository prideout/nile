import grid
import vector

# Vec2f coords are (0,0) at top-left, (1,1) at bottom-right.
# Vec3ii coords are (x,y,z) are integers where x and y are in 0..<(2^z)
#
# For futher reading:
#    https://github.com/mapbox/mbtiles-spec
#    https://blog.mapbox.com/how-we-serve-faster-maps-from-mapbox-73110dce59bc
#    https://openmaptiles.com/downloads/planet/

type Tile* = ref object
    base: Grid
    data*: Grid
    index: Vec3ii
    resolution: int
    children: array[4, Tile]

proc getTileCenter*(tile: Tile): Vec2f =
    let
        ntiles = float(1 shl tile.index.z)
        x = (0.5 + float(tile.index.x)) / ntiles
        y = (0.5 + float(tile.index.y)) / ntiles
    (float32(x), float32(y))

proc getTileBounds*(tile: Tile): Viewport =
    let
        ntiles = float(1 shl tile.index.z)
        x0 = (0.0 + float(tile.index.x)) / ntiles
        y0 = (0.0 + float(tile.index.y)) / ntiles
        x1 = (1.0 + float(tile.index.x)) / ntiles
        y1 = (1.0 + float(tile.index.y)) / ntiles
    (float32(x0), float32(y0), float32(x1), float32(y1))

proc genSplat(size: int, center: Vec2f, scale: float): Grid =
    result = newGrid(size, size)
    let dx = 1.0f / float32(size)
    var y = 0.0f
    var i = 0
    for row in 0..<size:
        var x = 0.0f
        for col in 0..<size:
            var t = scale * len((x,y) - center)
            var v = FilterHermite.function(t)
            result.data[i] = v * v * v
            inc i
            x += dx
        y += dx

proc generateRootTile*(resolution, seed: int): Tile =
    let size = resolution
    let splat = genSplat(size, (0.5f, 0.5f), 1.0f)
    let view = ENTIRE
    var vp = view * 4.0f
    var g = generateGradientNoise(seed, size, size, vp)
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 1, size, size, vp) / 2
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 2, size, size, vp) / 4
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 3, size, size, vp) / 8
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 4, size, size, vp) / 16
    g += splat / 2
    g *= splat
    new(result)
    result.index = (0'i64, 0'i64, 0'i64)
    result.data = (1.0 - g) * g.step(0.1)
    result.resolution = resolution

proc generateChildren*(tile: Tile): void =
    discard
