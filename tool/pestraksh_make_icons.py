"""PestRaksh: make this app's icons from the PestRaksh logo, keeping every existing file name and size.

Writes the Android launcher, adaptive and notification icons, the iOS app icons, the
flutter_launcher_icons masters (assets/logo) and the splash logo (assets/images/png/pestraksh_logo.png).
The logo can be the website's transparent PestRaksh logo, or this repo's own
assets/images/png/pestraksh_logo.png (900 px wide, already trimmed).

Needs Python 3 with Pillow (pip install pillow). Run from anywhere:
    python3 tool/pestraksh_make_icons.py assets/images/png/pestraksh_logo.png . [preview.png]
The optional third argument is a preview sheet to check the result by eye.
Used for both PestRaksh apps (technician and customer) on 25-26 Nov 2026."""
import glob
import os
import sys

from PIL import Image, ImageDraw

logo_path, app = sys.argv[1], sys.argv[2]
logo = Image.open(logo_path).convert("RGBA")
bbox = logo.getbbox()  # trim transparent margins
logo = logo.crop(bbox)
WHITE = (255, 255, 255, 255)


def fit(img, box_w, box_h):
    r = min(box_w / img.width, box_h / img.height)
    return img.resize((max(1, round(img.width * r)), max(1, round(img.height * r))), Image.LANCZOS)


def centred(size, content_w_ratio, bg=None, rounded=0.0):
    """Square canvas with the logo centred, content at most content_w_ratio of the side."""
    S = 1024
    canvas = Image.new("RGBA", (S, S), bg or (0, 0, 0, 0))
    if rounded:
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * rounded), fill=255)
        base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        base.paste(canvas, (0, 0), mask)
        canvas = base
    l = fit(logo, S * content_w_ratio, S * content_w_ratio)
    canvas.alpha_composite(l, ((S - l.width) // 2, (S - l.height) // 2))
    return canvas.resize((size, size), Image.LANCZOS)


def save(img, path, mode):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if mode == "RGB":
        flat = Image.new("RGB", img.size, (255, 255, 255))
        flat.paste(img, (0, 0), img)
        flat.save(path, optimize=True)
    else:
        img.save(path, optimize=True)


made = []
res = f"{app}/android/app/src/main/res"

# Android legacy launcher icon: white rounded square with the logo.
for f in sorted(glob.glob(f"{res}/mipmap-*/launcher_icon.png")):
    n = Image.open(f).width
    save(centred(n, 0.80, WHITE, rounded=0.18), f, "RGBA"); made.append(f)

# Android adaptive foreground (the XML insets it 16% on each side): logo on transparent.
for f in sorted(glob.glob(f"{res}/drawable-*/ic_launcher_foreground.png")):
    n = Image.open(f).width
    save(centred(n, 0.86), f, "RGBA"); made.append(f)

# Android notification icon: white silhouette on transparent (Android tints it).
alpha = logo.split()[3]
silhouette = Image.new("RGBA", logo.size, (255, 255, 255, 0))
silhouette.putalpha(alpha.point(lambda a: 255 if a > 96 else 0))
for density, n in [("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)]:
    S = 1024
    c = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    l = fit(silhouette, S * 0.94, S * 0.94)
    c.alpha_composite(l, ((S - l.width) // 2, (S - l.height) // 2))
    p = f"{res}/drawable-{density}/ic_notification.png"
    save(c.resize((n, n), Image.LANCZOS), p, "RGBA"); made.append(p)

# iOS app icons: full square, no transparency (iOS rounds the corners itself).
for f in sorted(glob.glob(f"{app}/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png")):
    n = Image.open(f).width
    save(centred(n, 0.80, WHITE), f, "RGB"); made.append(f)

# Master files used by flutter_launcher_icons (pubspec), so a future regeneration gives the same icons.
save(centred(1024, 0.80, WHITE), f"{app}/assets/logo/app_icon.png", "RGB"); made.append("assets/logo/app_icon.png")
save(centred(1024, 0.86), f"{app}/assets/logo/app_icon_foreground.png", "RGBA"); made.append("assets/logo/app_icon_foreground.png")

# Splash screen logo (wide, transparent), shown by the Flutter splash.
splash = fit(logo, 900, 900)
save(splash, f"{app}/assets/images/png/pestraksh_logo.png", "RGBA"); made.append("assets/images/png/pestraksh_logo.png")

# Preview sheet for checking by eye.
sheet = Image.new("RGBA", (1100, 330), (238, 238, 238, 255))
x = 20
for p in [f"{res}/mipmap-xxxhdpi/launcher_icon.png", f"{app}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"]:
    im = Image.open(p).convert("RGBA"); sheet.alpha_composite(im, (x, 20)); x += im.width + 30
fg = Image.open(f"{res}/drawable-xxxhdpi/ic_launcher_foreground.png").convert("RGBA")
circle = Image.new("RGBA", fg.size, (255, 255, 255, 255)); circle.alpha_composite(fg)
m = Image.new("L", fg.size, 0); ImageDraw.Draw(m).ellipse([0, 0, fg.width - 1, fg.height - 1], fill=255)
inset = int(fg.width * 0.16); circ = Image.new("RGBA", fg.size, (0, 0, 0, 0))
small = circle.resize((fg.width - 2 * inset, fg.height - 2 * inset)); bg = Image.new("RGBA", fg.size, (255, 255, 255, 255)); bg.alpha_composite(small, (inset, inset))
circ.paste(bg, (0, 0), m); sheet.alpha_composite(circ.resize((192, 192)), (x, 20)); x += 222
dark = Image.new("RGBA", (96, 96), (40, 40, 40, 255)); dark.alpha_composite(Image.open(f"{res}/drawable-xxxhdpi/ic_notification.png"))
sheet.alpha_composite(dark, (x, 20)); x += 126
sp = Image.open(f"{app}/assets/images/png/pestraksh_logo.png"); sheet.alpha_composite(fit(sp, 300, 200), (x, 20))
sheet.save(sys.argv[3] if len(sys.argv) > 3 else "icons_preview.png")
print(f"{len(made)} files written")
