#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import strformat
import nile

var verbose = false

const NFRAMES = 30
const TILE_RESOLUTION = 1024 # 3840
const VIEWPORT_RESOLUTION = int(TILE_RESOLUTION / 4)

proc enlargeViewport(vp: Viewport, mag: float): Viewport =
    let
        c = vp.center()
        s = vp.size() / 2
    return viewport(c - s * mag, c + s * mag)

proc shrinkViewport(vp: Viewport, src: Vec2f, resolution: int, dst: Vec2f = (0.5f, 0.5f),
        zoomspeed: float32 = 10, panspeed: float32 = 0.05): Viewport =
    let
        vpextent = vp.upper() - vp.lower()
        pandir = src - dst
        pandelta = panspeed * pandir
        zoomdelta = zoomspeed * vpextent / float32(resolution)
    return viewport(vp.lower + pandelta + zoomdelta, vp.upper + pandelta - zoomdelta)

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

proc genIsland(seed: int, size: int, view: Viewport = ENTIRE): Grid =
    let
        s2 = size * 2
        splat = newGrid("000 010 000").resize(s2, s2, FilterHermite)
    var vp = enlargeViewport(view, 32)
    if verbose: echo "    Layer 1..."
    var g = generateGradientNoise(seed, s2, s2, vp)
    if verbose: echo "    Layer 2..."
    vp = enlargeViewport(vp, 2)
    g += generateGradientNoise(seed, s2, s2, vp) / 2
    if verbose: echo "    Layer 3..."
    vp = enlargeViewport(vp, 2)
    g += generateGradientNoise(seed, s2, s2, vp) / 4
    if verbose: echo "    Layer 4..."
    vp = enlargeViewport(vp, 2)
    g += generateGradientNoise(seed, s2, s2, vp) / 8
    g += splat / 2
    g *= splat
    let
        r0 = int(float(size) - size / 2)
        r1 = int(float(size) + size / 2)
        g2 = g.step(0.1)
        g3 = g2 - g * g2 * 1.0f
    return g3.crop(r0, r0, r1, r1)

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

echo "Generating island..."
var island = genIsland(9, TILE_RESOLUTION, view)

echo "Marching segment..."
let
    p0 = (0.6f, 0.0f)
    p1 = (0.4f, 1.0f)
    target = island.marchSegment(p0, p1)

echo "Shrinking image..."
island = island.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)

echo "Drawing overlay..."
let canvas = newCanvas(island.width, island.height)
canvas.setColor(0.5, 0.0, 0.0, 0.75).moveTo(p0).lineTo(p1).stroke()
canvas.setColor(0.0, 0.0, 0.0, 1.0).circle(target, radius = 0.01).fill()
canvas.setColor(1.0, 1.0, 1.0, 1.0).circle(target, radius = 0.01).stroke()

echo "Saving PNG..."
var im = newImageFromLuminance(island)
echo "    Converting canvas..."
let overlay = canvas.toImage()
echo "    Compositing..."
im = im.addOverlay(overlay)
echo "    Saving..."
im.savePNG("big.png")

for frame in 0..<NFRAMES:
    let fname = fmt"frame-{frame:03}.png"
    echo fmt"{fname} ({view.lower.x:+05.2},{view.lower.y:+05.2} " &
        fmt"{view.upper.x:+05.2},{view.upper.y:+05.2}) " &
        fmt"{target.x:+05.2},{target.y:+05.2}"
    view = shrinkViewport(view, target, VIEWPORT_RESOLUTION)
