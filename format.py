from PIL import Image
import sys

if __name__ == "__main__":
  print(Image.open(sys.argv[1]).format)
