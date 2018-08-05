#!/usr/bin/env nim c -d:release --boundChecks:off --verbosity:0 --run

#!/usr/bin/env nim c --debugger:native --run

import strformat
import nile
import os

const NFRAMES = 2
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
        isles[seed] = generateRootTile(128, seed).mask
    let
        row0 = hstack(isles[0], isles[1], isles[2], isles[3])
        row1 = hstack(isles[4], isles[5], isles[6], isles[7])
    vstack(row0, row1).drawGrid(4, 2, 0.3f).savePNG("_islands.png")
    showPNG("_islands.png")

let
    p0 = (0.6f, 0.0f)
    p1 = (0.4f, 1.0f)
var target: Vec2f

proc exportPNG(tile: Tile, frame: int, resolution: int): void =
    let
        island = tile.mask
        view = getTileBounds(tile)
        small = island.resize(resolution, resolution, FilterHermite)
        canvas = newCanvas(small.width, small.height)
        pt = target
    canvas.setColor(0.5, 0.0, 0.0, 0.75).moveTo(p0).lineTo(p1).stroke()
    canvas.setColor(0.0, 0.0, 0.0, 0.5).circle(pt, radius = 0.015).fill()
    canvas.setColor(1.0, 1.0, 1.0, 0.5).circle(pt, radius = 0.015).stroke()
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
    target = parentTile.mask.marchSegment(p0, p1)
    exportPNG(parentTile, frame=0, VIEWPORT_RESOLUTION)

    for frame in 1..<NFRAMES:
        let zoom = frame
        var childIndex = getTileAt(target, zoom)
        let childTile = generateChild(parentTile, childIndex)

        when false:
            target = transform(target, parentTile.index, childIndex)
            p0 = intersectRayBox(p1, hat(targetPt - p1), 0.0f, 0.0f, 1.0f, 1.0f)
        else:
            target = transform(target, parentTile.index, childIndex)

        exportPNG(childTile, frame, VIEWPORT_RESOLUTION)
        parentTile = childTile
