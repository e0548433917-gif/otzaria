# הופך צילום של הכותל לציור קווים: שקיפות = כהות הקו, כדי לצבוע אותו ב-CSS בצבע ערכת הנושא.
import sys
from PIL import Image, ImageFilter, ImageOps, ImageChops, ImageEnhance
src, out, crop_h = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("L")
im = im.crop((0, 0, im.width, crop_h))
g = ImageEnhance.Contrast(im).enhance(1.3)
inv = ImageOps.invert(g).filter(ImageFilter.GaussianBlur(5))
# color dodge: sketch = g / (1-inv)
import numpy as np
a = np.asarray(g, dtype=np.float32); b = np.asarray(inv, dtype=np.float32)
sk = np.clip(a * 255.0 / (255.0 - b + 1), 0, 255)
line = 255 - sk                       # כהות הקו
line = np.clip((line - 18) * 2.2, 0, 255)  # מנקה רעש עדין, מחזק קווים
# השמים: מעל קו הכותל אין קווים (הם חלקים) — הדילוג מטפל בזה לבד
alpha = Image.fromarray(line.astype("uint8")).filter(ImageFilter.SMOOTH)
# דהייה בתחתית, כדי שהציור ייגמר ברכות
h = alpha.height; fade = np.linspace(1, 1, h); fade[int(h*.85):] = np.linspace(1, 0, h - int(h*.85))
alpha = Image.fromarray((np.asarray(alpha, dtype=np.float32) * fade[:, None]).astype("uint8"))
rgba = Image.new("LA", alpha.size, 0); rgba.putalpha(alpha)
rgba.save(out, "WEBP", quality=55, method=6)
print(out, rgba.size)
