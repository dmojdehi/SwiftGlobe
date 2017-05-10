#!/usr/bin/env python
import sys
from PIL import Image
from math import pi, sin, cos, tan, atan2, hypot, floor
from numpy import clip

# get x,y,z coords from out image pixels coords
# i,j are pixel coords
# faceIdx is face number
# faceSize is edge length
def outImgToXYZ(i, j, faceIdx, faceSize):
    a = 2.0 * float(i) / faceSize
    b = 2.0 * float(j) / faceSize

    if faceIdx == 0: # back
        (x,y,z) = (-1.0, 1.0 - a, 1.0 - b)
    elif faceIdx == 1: # left
        (x,y,z) = (a - 1.0, -1.0, 1.0 - b)
    elif faceIdx == 2: # front
        (x,y,z) = (1.0, a - 1.0, 1.0 - b)
    elif faceIdx == 3: # right
        (x,y,z) = (1.0 - a, 1.0, 1.0 - b)
    elif faceIdx == 4: # top
        (x,y,z) = (b - 1.0, a - 1.0, 1.0)
    elif faceIdx == 5: # bottom
        (x,y,z) = (1.0 - b, a - 1.0, -1.0)

    return (x, y, z)

# convert using an inverse transformation
def convertFace(imgIn, imgOut, faceIdx):
    inSize = imgIn.size
    outSize = imgOut.size
    inPix = imgIn.load()
    outPix = imgOut.load()
    faceSize = outSize[0]

    for xOut in xrange(faceSize):
        for yOut in xrange(faceSize):
            (x,y,z) = outImgToXYZ(xOut, yOut, faceIdx, faceSize)
            theta = atan2(y,x) # range -pi to pi
            r = hypot(x,y)
            phi = atan2(z,r) # range -pi/2 to pi/2

            # source img coords
            uf = 0.5 * inSize[0] * (theta + pi) / pi
            vf = 0.5 * inSize[0] * (pi/2 - phi) / pi

            # Use bilinear interpolation between the four surrounding pixels
            ui = floor(uf)  # coord of pixel to bottom left
            vi = floor(vf)
            u2 = ui+1       # coords of pixel to top right
            v2 = vi+1
            mu = uf-ui      # fraction of way across pixel
            nu = vf-vi

            # Pixel values of four corners
            A = inPix[ui % inSize[0], clip(vi, 0, inSize[1]-1)]
            B = inPix[u2 % inSize[0], clip(vi, 0, inSize[1]-1)]
            C = inPix[ui % inSize[0], clip(v2, 0, inSize[1]-1)]
            D = inPix[u2 % inSize[0], clip(v2, 0, inSize[1]-1)]

            # interpolate
            (r,g,b) = (
              A[0]*(1-mu)*(1-nu) + B[0]*(mu)*(1-nu) + C[0]*(1-mu)*nu+D[0]*mu*nu,
              A[1]*(1-mu)*(1-nu) + B[1]*(mu)*(1-nu) + C[1]*(1-mu)*nu+D[1]*mu*nu,
              A[2]*(1-mu)*(1-nu) + B[2]*(mu)*(1-nu) + C[2]*(1-mu)*nu+D[2]*mu*nu )

            outPix[xOut, yOut] = (int(round(r)), int(round(g)), int(round(b)))

imgIn = Image.open(sys.argv[1])
inSize = imgIn.size
faceSize = inSize[0] / 4
components = sys.argv[1].rsplit('.', 2)

FACE_NAMES = {
  0: 'back',
  1: 'left',
  2: 'front',
  3: 'right',
  4: 'top',
  5: 'bottom'
}

for face in xrange(6):
  imgOut = Image.new("RGB", (faceSize, faceSize), "black")
  convertFace(imgIn, imgOut, face)
  imgOut.save(components[0] + "_" + FACE_NAMES[face] + "." + components[1])