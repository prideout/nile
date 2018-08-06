import grid
import vector
import strformat

# Vec2f coords are (0,0) at top-left, (1,1) at bottom-right.
# Vec3ii coords are (x,y,z) are integers where x and y are in 0..<(2^z)
#
# For futher reading:
#    https://github.com/mapbox/mbtiles-spec
#    https://blog.mapbox.com/how-we-serve-faster-maps-from-mapbox-73110dce59bc
#    https://openmaptiles.com/downloads/planet/

type Map* = ref object
    resolution: int
    seed: int

type Tile* = ref object
    elevation*: Grid
    mask*: Grid
    index*: Vec3ii
    map: Map
    children: array[4, Tile]

# Transform a coord from a parent tile space into its child's tile space.
proc transform*(pt: Vec2f, fromTile: Vec3ii, toTile: Vec3ii): Vec2f =
    assert toTile.z == fromTile.z + 1
    let
        nw = (fromTile.x * 2, fromTile.y * 2, fromTile.z + 1)
        ne = (fromTile.x * 2 + 1, fromTile.y * 2, fromTile.z + 1)
        sw = (fromTile.x * 2, fromTile.y * 2 + 1, fromTile.z + 1)
        se = (fromTile.x * 2 + 1, fromTile.y * 2 + 1, fromTile.z + 1)
    if toTile == nw: return pt * 2.0f
    if toTile == sw: return (pt.x * 2.0f, (pt.y - 0.5f) * 2.0f)
    if toTile == ne: return ((pt.x - 0.5f) * 2.0f, pt.y * 2.0f)
    if toTile == se: return ((pt.x - 0.5f) * 2.0f, (pt.y - 0.5f) * 2.0f)
    assert(false)

proc getTileCenter*(tile: Tile): Vec2f =
    let
        ntiles = float(1 shl tile.index.z)
        x = (0.5 + float(tile.index.x)) / ntiles
        y = (0.5 + float(tile.index.y)) / ntiles
    (float32(x), float32(y))

proc getTileAt*(p: Vec2f, z: int64): Vec3ii =
    let
        ntiles = float(1 shl z)
        x = int64(p.x * ntiles)
        y = int64(p.y * ntiles)
    (x, y, z)

proc getTileBounds*(tile: Tile): Viewport =
    let
        ntiles = float(1 shl tile.index.z)
        x0 = (0.0 + float(tile.index.x)) / ntiles
        y0 = (0.0 + float(tile.index.y)) / ntiles
        x1 = (1.0 + float(tile.index.x)) / ntiles
        y1 = (1.0 + float(tile.index.y)) / ntiles
    (float32(x0), float32(y0), float32(x1), float32(y1))

proc generateFalloff(size: int, view: Viewport): Grid =
    result = newGrid(size, size)
    let
        dx = (view.right - view.left) / float32(size)
        dy = (view.bottom - view.top) / float32(size)
    var y = view.top
    var i = 0
    for row in 0..<size:
        var x = view.left
        for col in 0..<size:
            let
                t = len((x,y) - (0.5f, 0.5f))
                v = FilterHermite.function(t)
            result.data[i] = v * v * v
            inc i
            x += dx
        y += dy

proc generateRootTile*(resolution, seed: int): Tile =
    let
        size = resolution
        view = ENTIRE
        falloff = generateFalloff(size, view)
        vp0 = view * 4.0f
        vp1 = vp0 * 2.0f
        vp2 = vp1 * 2.0f
        vp3 = vp2 * 2.0f
        vp4 = vp3 * 2.0f
    new(result)
    result.index = (0'i64, 0'i64, 0'i64)
    result.map = new Map
    result.map.resolution = resolution
    result.map.seed = seed
    var g = generateGradientNoise(seed, size, size, vp0)
    g *= 2.0f
    g += generateGradientNoise(seed + 1, size, size, vp1)
    g *= 2.0f
    g += generateGradientNoise(seed + 2, size, size, vp2)
    g *= 2.0f
    g += generateGradientNoise(seed + 3, size, size, vp3)
    g *= 2.0f
    g += generateGradientNoise(seed + 4, size, size, vp4)
    g /= 16
    g += falloff / 2
    g *= falloff
    result.elevation = g
    result.mask = g.step(0.1)

proc generateChild(child: Tile, parent: Tile, subview: Viewport): void =
    let
        map = child.map
        # zoom = child.index.z
        # seed = map.seed + int(zoom)
        size = map.resolution
        fsize = float(size)
        left = int(subview.left * fsize)
        top = int(subview.top * fsize)
        right = int(subview.right * fsize)
        bottom = int(subview.bottom * fsize)
    let e = parent.elevation.crop(left, top, right, bottom)
    child.elevation = e.resize(size, size, FilterGaussian)
    child.mask = child.elevation.step(0.1)

proc generateChild*(parent: Tile, index: Vec3ii): Tile =
    assert(index.z == parent.index.z + 1)
    let
        west = parent.index.x * 2
        east = west + 1
        north = parent.index.y * 2
        south = north + 1
    result = new Tile
    result.index = index
    result.map = parent.map
    if index.x == west and index.y == north:
        parent.children[0] = result
        generateChild(result, parent, (0.0f, 0.0f, 0.5f, 0.5f))
    elif index.x == east and index.y == north:
        parent.children[1] = result
        generateChild(result, parent, (0.5f, 0.0f, 1.0f, 0.5f))
    elif index.x == west and index.y == south:
        parent.children[2] = result
        generateChild(result, parent, (0.0f, 0.5f, 0.5f, 1.0f))
    elif index.x == east and index.y == south:
        parent.children[3] = result
        generateChild(result, parent, (0.5f, 0.5f, 1.0f, 1.0f))
    else:
        echo fmt"Cannot generate child {index.x:03} {index.y:03} {index.z:03}"
        assert(false)
