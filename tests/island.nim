#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import strformat
import nile

var verbose = false

const NFRAMES = 30
const TILE_RESOLUTION = 2048 # 3840
const VIEWPORT_RESOLUTION = int(TILE_RESOLUTION / 4)

proc enlargeViewport*(vp: Viewport, mag: float): Viewport =
    let c = vp.center()
    let s = vp.size() / 2
    return viewport(c - s * mag, c + s * mag)

proc shrinkViewport(vp: Viewport, src: Vec2f, resolution: int, dst: Vec2f = (0.5f, 0.5f),
        zoomspeed: float32 = 10, panspeed: float32 = 0.05): Viewport =
    let
        vpextent = vp.upper() - vp.lower()
        pandir = src - dst
        pandelta = panspeed * pandir
        zoomdelta = zoomspeed * vpextent / float32(resolution)
    return viewport(vp.lower + pandelta + zoomdelta, vp.upper + pandelta - zoomdelta)

proc `*`(vp: Viewport, scale: float32): Viewport =
    (vp.left * scale, vp.top * scale, vp.right * scale, vp.bottom * scale)

proc marchSegment(grid: Grid, p0: Vec2f, p1: Vec2f): Vec2f =
    let
        delta = 1 / float(max(grid.width, grid.height))
        dir = delta * (p1 - p0).hat()
        sign0 = grid.sampleNearest(p0.x, p0.y) <= 0
    var
        p = p0
        sign = sign0
    while sign == sign0:
        p += dir
        sign = grid.sampleNearest(p.x, p.y) <= 0
        if p.x < 0 or p.x > 1 or p.y < 0 or p.y > 1: break
    return p

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

proc genIsland(seed: int, size: int, view: Viewport = ENTIRE): Grid =
    let splat = genSplat(size, (0.5f, 0.5f), 1.0f)
    var vp = view * 16.0f
    if verbose: echo "    Layer 1..."
    var g = generateGradientNoise(seed, size, size, vp)
    if verbose: echo "    Layer 2..."
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 1, size, size, vp) / 2
    if verbose: echo "    Layer 3..."
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 2, size, size, vp) / 4
    if verbose: echo "    Layer 4..."
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 3, size, size, vp) / 8
    if verbose: echo "    Layer 5..."
    vp = vp * 2.0f
    g += generateGradientNoise(seed + 4, size, size, vp) / 16
    g += splat / 2
    g *= splat
    return (1.0 - g) * g.step(0.1)

var view: Viewport = (0.375f, 0.375f, 0.625f, 0.625f)

when true:
    echo "Generating island test grid..."
    var isles: array[8, Grid]
    for seed in 0..<isles.len():
        isles[seed] = genIsland(seed, 128, view)
    let
        row0 = hstack(isles[0], isles[1], isles[2], isles[3])
        row1 = hstack(isles[4], isles[5], isles[6], isles[7])
    vstack(row0, row1).drawGrid(4, 2, 0.3f).savePNG("_islands.png")

let
    p0 = (0.6f, 0.0f)
    p1 = (0.4f, 1.0f)
var target: Vec2f

proc exportPNG(island: Grid, frame: int): void =
    echo "Shrinking image..."
    let small = island.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
    echo "Drawing overlay..."
    let canvas = newCanvas(small.width, small.height)
    canvas.setColor(0.5, 0.0, 0.0, 0.75).moveTo(p0).lineTo(p1).stroke()
    canvas.setColor(0.0, 0.0, 0.0, 1.0).circle(target, radius = 0.01).fill()
    canvas.setColor(1.0, 1.0, 1.0, 1.0).circle(target, radius = 0.01).stroke()
    echo "Saving PNG..."
    var im = newImageFromLuminance(small)
    let overlay = canvas.toImage()
    im = im.addOverlay(overlay)
    im.savePNG(fmt"frame-{frame:03}.png")

echo "Generating island..."
var island = genIsland(9, TILE_RESOLUTION, view)

echo "Marching segment..."
target = island.marchSegment(p0, p1)
    
exportPNG(island, frame=0)

for frame in 0..<NFRAMES:
    let fname = fmt"frame-{frame:03}.png"
    echo fmt"{fname} ({view.lower.x:+05.2},{view.lower.y:+05.2} " &
        fmt"{view.upper.x:+05.2},{view.upper.y:+05.2}) " &
        fmt"{target.x:+05.2},{target.y:+05.2}"
    view = shrinkViewport(view, target, VIEWPORT_RESOLUTION)
