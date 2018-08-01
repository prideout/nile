[![Build Status](https://travis-ci.org/prideout/lava.svg?branch=master)](https://travis-ci.org/prideout/lava)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/prideout/clumpy/blob/master/LICENSE)

**Nile** is a library for manipulating and generating images.

For more information, read [the docs]().

<!--

# INFINITE ISLAND

    Slow and Crashy with size = 3840
        Debug crash with debug mode

    Test your resampling code by minifying

    Window is 960x540
    Viewport is 960x960
    BaseTile (L_f32) and CurrentTile (L_f32) are both 3840x3840.
    Initial Viewport is 0.375,0.375 through 0.625, 0.625

    see notes later in this file

    making video
        import os
        execShellCmd(command: string)
        https://en.wikibooks.org/wiki/FFMPEG_An_Intermediate_Guide/image_sequence
        ffmpeg -i image-%03d.png video.webm

# SEE ALSO

    https://nimble.directory/search?query=graphics
    http://rnduja.github.io/2015/10/21/scientific-nim/
    https://narimiran.github.io/2018/05/10/python-numpy-nim.html
    https://github.com/stavenko/nim-glm
    https://github.com/unicredit/neo
    http://entropymine.com/imageworsener/pixelmixing/
    Canvas
        Model from Skia classes
        https://github.com/memononen/nanosvg
        https://nimble.directory/pkg/nimagg (the AGG library, hand ported from C, seems nice)
        https://nimble.directory/pkg/suffer (looks like a personal project; draws 2D shapes with pure nim and depends on a few C libraries)

# TO BE DONE

    Grid
        float => float32, int => int32
        use mapIt and applyIt
        private width & height in favor of getters
        maybe even private data?
        templatize the pattern of looping over rows, cols, and having "x y row col", e.g.
            with pixels(grid):
                pixel = pixel + 1.0f - x + y / float(row)
        addBorder (default argument of 1)
        blitFrom

    Image
        pillow suite of things
        colorspace: linear / srgb
        toDataString takes CLAMP or NORMALIZE

    Canvas
        port from Skia
        Wrote program that creates diagram showing the relationship between
            Grid / Image / Canvas

    automate tests
        keep it simple, just check in the PNG files and diff them with a simple nim program

    open source & nimble
        "The top level of the package source directory should contain at most one module, "
        "named 'cairo.nim', but a file named 'cairowin32.nim' was found. This will be an error "
        "in the future."

# THE INFINITE ISLAND

    "Always be minifying"

    - In other words, the most recently rendered tile is always between 2x and 4x the viewport size.
    - Magnifying produces pixelation or blurriness
    - Evaluating noise in real time causes peninsulas to morph into islands, etc.
    - We get free AA because we're supersampling
    - If the tile were always bigger than the viewport, we can do fun things with distance fields.

    Strategy:
    - Window is 960x540, Viewport is 960x960 BaseTile (L_f32) and CurrentTile (L_f32) are both 3840x3840.
    - Initial Viewport is 0.375,0.375 through 0.625, 0.625
    - Base layer is a carefully scaled / offset Hermite splat that crosses 0 at about 1/16 (0.0625)
    - Two floating-point tiles: BaseTile (low freq only) and CurrentTile (BaseTile + 3 layers).
    - When zooming, as soon as minification hits the 2x boundary (i.e. when vp extent is >= 0.5)
    - Re-render the CurrentTile (but with only 1 additional layer) at full res using the current vp
    - Normalize CurrentTile pixel values to [-1,+1] but do not offset (0 should not move).
    - Copy CurrentTile to BaseTile.
    - Add 3 noise layers to CurrentTile.
    - Recompute the FocusPoint by marching the FocusRay (.5,.5) to (0.7,-1.0)
    - Reset the Viewport to 0.375,0.375 through 0.625, 0.625

    According to wikipedia, Mandelbrot is an "escape-time" fractal whereas Brownian surfaces are "random
    fractals" because they are generated via stochastic rules. Arbitrary precision libraries like BLAH
    can help.

    Binary Ninja or github cutter

# HOW TO BUILD DOCS

    brew install mkdocs
    pip install mkdocs-material
    mkdocs serve
    mkdocs build -d /tmp/docs
    git checkout gh-pages; rsync /tmp/docs ./

-->