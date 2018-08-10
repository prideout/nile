#!/usr/bin/env nim c --run

import nile

const diagramScale = 16

let original = newGrid("""
    00000000
    00111100
    00100100
    00111100
    00100000
    00100000
    00100000
    00000000""")
original.setPixel(7, 7, 0.5)
var mag = original.resizeBoxFilter(11, 11).resizeNearestFilter(diagramScale).drawGrid(11, 11)
var ide = original.resizeBoxFilter(8, 8).resizeNearestFilter(diagramScale).drawGrid(8, 8)
var min = original.resizeBoxFilter(5, 5).resizeNearestFilter(diagramScale).drawGrid(5, 5)
min.savePNG("min0.png")
mag.savePNG("mag0.png")
ide.savePNG("ide0.png")

let tiny = newGrid("000 010 000")
min = tiny.resizeBoxFilter(1, 1).resizeNearestFilter(diagramScale).drawGrid(1, 1)
mag = tiny.resizeBoxFilter(5, 5).resizeNearestFilter(diagramScale).drawGrid(5, 5)
ide = tiny.resizeBoxFilter(9, 9).resizeNearestFilter(diagramScale).drawGrid(9, 9)
min.savePNG("min1.png")
mag.savePNG("mag1.png")
ide.savePNG("ide1.png")

let row = newGrid("010")
mag = row.resize(5, 1, FilterHermite).resizeNearestFilter(diagramScale).drawGrid(5, 1, 1)
mag.savePNG("mag2.png")
mag = tiny.resize(5, 5, FilterHermite).resizeNearestFilter(diagramScale).drawGrid(5, 5, 1)
mag.savePNG("mag3.png")
mag = tiny.resize(128, 128, FilterHermite).drawGrid(1, 1, 1)
mag.savePNG("mag4.png")

let nearest = original.resizeNearestFilter(1000, 1000).resizeBoxFilter(100, 100)
let hermite = original.resize(1000, 1000, FilterHermite).resizeBoxFilter(100, 100)
let gauss = original.resize(1000, 1000, FilterGaussian).resizeBoxFilter(100, 100)
let triangle = original.resize(1000, 1000, FilterTriangle).resizeBoxFilter(100, 100)
(1 - hstack(nearest, hermite, gauss, triangle)).drawGrid(4, 1, 1).savePNG("min2.png")
(0.2 + 0.5 * vstack(nearest, hermite, gauss, triangle)).drawGrid(1, 4, 1).savePNG("min3.png")

let grads = 0.5f + generateGradientNoise(42, 256, 256, 2.0f) * 0.5f
grads.drawGrid(1, 1, 1).savePNG("grads1.png")
