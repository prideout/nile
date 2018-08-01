import grid
import image
import nimPNG

proc savePNG*(g: Grid, filename: string): void =
    discard savePNG(filename, g.toDataString(), LCT_GREY, 8, g.width, g.height)

proc savePNG*(img: Image, filename: string): void =
    discard savePNG(filename, img.toDataString(), LCT_RGBA, 8, img.width, img.height)
