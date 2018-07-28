# Quick start

**nile** is a library for manipulating and generating images. It is written purely in nim, but
depends on other packages for reading and writing image files, such as **nimPNG**.

## Overview

In nile parlance, a **Grid** is a two-dimensional array of scalar floating-point data. It usually
holds one of the RGB color planes or an alpha mask, but it could represent anything you like, such
as a height map.

<!-- Grids can serialize itself as npy files, but not image files. (not good for normal maps...) -->

As a user, you'll probably be mostly be interacting with **Image**, which wraps a list of grids
tagged with semantics such as RED or ALPHA, as well as individual animation frames.
This class offers an easy-to-use high level interface for working with image files and videos.

Nile also offers a **Canvas** class for creating simple vector drawings. You can use this to fill a
region with color or draw lines.

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


