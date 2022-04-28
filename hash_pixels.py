import subprocess, sys, numpy, hashlib
from PIL import Image, ImageChops


def is_gray(im):
  rgb = im.split()
  if ImageChops.difference(rgb[0], rgb[1]).getextrema()[1] != 0:
    return False
  if ImageChops.difference(rgb[0], rgb[2]).getextrema()[1] != 0:
    return False
  return True


def has_no_alpha(im):
  return im.getextrema()[-1][0] == 255


def main():
  im = Image.open(sys.argv[1])
  if im.mode == "RGB":
    if is_gray(im):
      arr = numpy.array(im.convert("L"))
      print(hashlib.md5(arr).hexdigest())
      return

  if im.mode == "RGBA":
    if has_no_alpha(im) and is_gray(im):
      arr = numpy.array(im.convert("L"))
      print(hashlib.md5(arr).hexdigest())
      return
    elif has_no_alpha(im):
      arr = numpy.array(im.convert("RGB"))
      print(hashlib.md5(arr).hexdigest())
      return
    elif is_gray(im):
      arr = numpy.array(im.convert("LA"))
      print(hashlib.md5(arr).hexdigest())
      return

  if im.mode == "LA":
    if has_no_alpha(im):
      arr = numpy.array(im.convert("L"))
      print(hashlib.md5(arr).hexdigest())
      return

  arr = numpy.array(im)
  print(hashlib.md5(arr).hexdigest())


if __name__ == "__main__":
  main()
