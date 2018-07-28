# Quick start

**Nile** is a library for manipulating and generating images. It is written purely in nim, and
has dependencies on just a couple other packages for reading and writing image files (**nimPNG**).

Nile is hosted on GitHub at [prideout/nile](https://github.com/prideout/nile).

## Overview

Nile's **Grid** object is a two-dimensional array of scalar floating-point data. It usually
holds one of the RGB color planes or an alpha mask, but it can represent anything you like, such
as a height map.

As a user, you'll mostly interact with **Image**, which is a container of grids that exposes an
easy-to-use API for working with image files and videos.

An image associates each grid with a semantic such as RED or ALPHA, and potentially groups them into
animation frames. Behind the scenes, it can evict grids from memory or load them in lazily, but
this behavior is shielded from users.

Nile also defines a **Canvas** object for creating simple vector drawings. You can use this to fill
a region with color or draw lines.

## Examples

### Create a thumbnail

Minify an image using the default filter.

~~~~~~~~~~~~~~~~~~~nim
import nile
image = openImage("test.png")
image.resized(12, 12).save("resized.png")
~~~~~~~~~~~~~~~~~~~

*show a diptych here*

### Add an alpha channel

Add an alpha channel based on pixel brightness.

~~~~~~~~~~~~~~~~~~~python
import nile
image = openImage("test.png")
grid = image.getLuminance()
image.setAlpha(grid)
image.save("semitransparent.png")
~~~~~~~~~~~~~~~~~~~

*show a diptych here*

### Apply Gaussian blur

### Create a 2x2 mosaic

hstack + vstack


