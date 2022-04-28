import subprocess, sys, shutil, time, os
from PIL import Image, ImageChops

cjxl_args = ["cjxl", "-q", "100", "-e", "9", "-E", "3", "-I", "1"]


def is_gray(im):
  rgb = im.split()
  if ImageChops.difference(rgb[0], rgb[1]).getextrema()[1] != 0:
    return False
  if ImageChops.difference(rgb[0], rgb[2]).getextrema()[1] != 0:
    return False
  return True


def has_no_alpha(im):
  return im.getextrema()[-1][0] == 255


def encode(file):
  subprocess.run(cjxl_args + [file, file + ".jxl"], capture_output=True)
  return file + ".jxl"


def main():
  inputs = [sys.argv[1]]

  im = Image.open(sys.argv[1])
  if im.mode == "RGB":
    if is_gray(im):
      im.convert("L").save(sys.argv[1] + "_L.png")
      inputs.append(sys.argv[1] + "_L.png")

  if im.mode == "RGBA":
    if has_no_alpha(im) and is_gray(im):
      im.convert("L").save(sys.argv[1] + "_L.png")
      inputs.append(sys.argv[1] + "_L.png")

    elif has_no_alpha(im):
      im.convert("RGB").save(sys.argv[1] + "_RGB.png")
      inputs.append(sys.argv[1] + "_RGB.png")

    elif is_gray(im):
      im.convert("LA").save(sys.argv[1] + "_LA.png")
      inputs.append(sys.argv[1] + "_LA.png")

  if im.mode == "LA":
    if has_no_alpha(im):
      im.convert("L").save(sys.argv[1] + "_L.png")
      inputs.append(sys.argv[1] + "_L.png")

  im.save(sys.argv[1] + ".png")
  inputs.append(sys.argv[1] + ".png")

  outputs = []
  for file in inputs:
    outputs.append(encode(file))

  outputs.sort(key=lambda f: os.path.getsize(f))
  shutil.copyfile(outputs[0], sys.argv[2])

  while True:
    try:
      [os.remove(f) for f in inputs[1:] if os.path.exists(f)]
      [os.remove(f) for f in outputs if os.path.exists(f)]
      break
    except:
      time.sleep(0.5)

  p = subprocess.run(["cjxl", "-V"],
                     capture_output=True,
                     universal_newlines=True)

  print(p.stdout.split("\n")[0])
  print(" ".join(cjxl_args))


if __name__ == "__main__":
  main()
