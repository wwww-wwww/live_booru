from PIL import Image
import sys

if __name__ == "__main__":
  im = Image.open(sys.argv[1])
  print(im.getextrema()[-1][0] < 255)
