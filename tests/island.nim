#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import strformat
import nile
import os

const NFRAMES = 0
const VIEWPORT_RESOLUTION = 256

proc enlargeViewport*(vp: Viewport, mag: float): Viewport =
    let c = vp.center()
    let s = vp.size() / 2
    return viewport(c - s * mag, c + s * mag)

proc shrinkViewport*(vp: Viewport, src: Vec2f, resolution: int, dst: Vec2f = (0.5f, 0.5f),
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

proc showPNG(fname: string): void =
    discard execShellCmd fmt"imgcat {fname}"

when true:
    echo "Generating island test grid..."
    var isles: array[8, Grid]
    for seed in 0..<isles.len():
        isles[seed] = generateRootTile(128, seed).data
    let
        row0 = hstack(isles[0], isles[1], isles[2], isles[3])
        row1 = hstack(isles[4], isles[5], isles[6], isles[7])
    vstack(row0, row1).drawGrid(4, 2, 0.3f).savePNG("_islands.png")
    showPNG("_islands.png")

let
    p0 = (0.6f, 0.0f)
    p1 = (0.4f, 1.0f)
var target: Vec2f

proc exportPNG(tile: Tile, frame: int): void =
    let
        island = tile.data
        view = getTileBounds(tile)
        small = island.resize(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION, FilterHermite)
        canvas = newCanvas(small.width, small.height)
        q0 = (p0 - (view.left, view.top)) / (view.right - view.left)
        q1 = (p1 - (view.left, view.top)) / (view.right - view.left)
        pt = target
        qt = (pt - (view.left, view.top)) / (view.right - view.left)
    canvas.setColor(0.5, 0.0, 0.0, 0.75).moveTo(q0).lineTo(q1).stroke()
    canvas.setColor(0.0, 0.0, 0.0, 0.5).circle(qt, radius = 0.015).fill()
    canvas.setColor(1.0, 1.0, 1.0, 0.5).circle(qt, radius = 0.015).stroke()
    var im = newImageFromLuminance(small)
    let overlay = canvas.toImage()
    im = im.addOverlay(overlay)
    var fname = fmt"frame-{frame:03}.png"
    im.savePNG(fname)
    showPNG(fname)

when NFRAMES > 0:
    echo "Generating root..."
    var parentTile = generateRootTile(2048, 9)

    echo "Marching segment..."
    target = parentTile.data.marchSegment(p0, p1)
    echo fmt"{target.x} , {target.y}"
    exportPNG(parentTile, frame=0)

    for frame in 1..<NFRAMES:
        let zoom = frame
        let childIndex = getTileAt(target, zoom)
        echo fmt"{frame:03} :: {childIndex.x:03} {childIndex.y:03}"
        let childTile = generateChild(parentTile, childIndex)
        # echo fmt"VP = {view.left:7.4} {view.top:7.4} {view.right:7.4} {view.bottom:7.4}"
        exportPNG(childTile, frame)
        parentTile = childTile
