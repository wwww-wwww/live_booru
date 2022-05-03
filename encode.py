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


def encode(file, out, extra_args):
  p = subprocess.run(cjxl_args + extra_args + [file, out + ".jxl"],
                     capture_output=True)
  if p.returncode != 0: exit(1)
  return out + ".jxl"


def main():
  inputs = [(sys.argv[1], sys.argv[1], [])]

  im = Image.open(sys.argv[1])
  if im.format == "JPEG":
    inputs.append((sys.argv[1], sys.argv[1] + ".j", ["-j"]))

  outputs = []
  for file in inputs:
    outputs.append((encode(*file), file[2]))

  outputs.sort(key=lambda f: os.path.getsize(f[0]))
  shutil.copyfile(outputs[0][0], sys.argv[2])

  while True:
    try:
      [os.remove(f[0]) for f in outputs if os.path.exists(f[0])]
      break
    except:
      time.sleep(0.5)

  p = subprocess.run(["cjxl", "-V"],
                     capture_output=True,
                     universal_newlines=True)

  print(p.stdout.split("\n")[0])
  print(" ".join(cjxl_args + outputs[0][1]))


if __name__ == "__main__":
  main()
