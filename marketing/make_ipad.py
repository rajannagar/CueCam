#!/usr/bin/env python3
"""Generate iPad App Store marketing images by compositing simulator screenshots
into device frame mockups with headline text, matching the iPhone marketing style."""

from PIL import Image, ImageDraw, ImageFont
import os, math

RAW = os.path.expanduser("~/Documents/CueCam/marketing/ipad/raw")
OUT = os.path.expanduser("~/Documents/CueCam/marketing/ipad")

# Canvas matches iPad Pro 13" native simulator output
CW, CH = 2064, 2752

# Colors
WARM_BG   = (242, 237, 226)
DARK_BG   = (22, 20, 18)
WARM_TEXT = (28, 24, 18)
LIGHT_TEXT= (238, 232, 220)
SUBTEXT_WARM = (100, 90, 75)
SUBTEXT_DARK = (160, 150, 135)

# Fonts
FONT_DIR = "/System/Library/Fonts"
def font(name, size):
    try:
        return ImageFont.truetype(os.path.join(FONT_DIR, name), size)
    except:
        return ImageFont.load_default()

def font_ttc(name, size, index=0):
    try:
        return ImageFont.truetype(os.path.join(FONT_DIR, name), size, index=index)
    except:
        return ImageFont.load_default()

HEADLINE_FONT = font_ttc("HelveticaNeue.ttc", 92, index=1)  # Heavy/Black weight
SUBHEAD_FONT  = font_ttc("HelveticaNeue.ttc", 46, index=7)  # Regular weight

# iPad frame geometry on canvas
# Frame sized to match iPad Pro 13" aspect ratio (2048:2732 = 3:4)
# Available vertical space below 430px top zone, 50px bottom margin
FRAME_Y = 430
FRAME_H = CH - FRAME_Y - 50   # 2272
FRAME_W = int(FRAME_H * 2048 / 2732) + 56  # screen ratio + 2x bezel ≈ 1748
FRAME_X = (CW - FRAME_W) // 2
FRAME_R = 72           # corner radius of device shell

BEZEL = 28             # bezel thickness inside frame
CAM_R = 8              # front camera dot radius

# Screen area inside frame
SCREEN_X = FRAME_X + BEZEL
SCREEN_Y = FRAME_Y + BEZEL
SCREEN_W = FRAME_W - 2 * BEZEL
SCREEN_H = FRAME_H - 2 * BEZEL


def rounded_rect_mask(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill)


def draw_ipad_frame(canvas, dark_theme=False):
    d = ImageDraw.Draw(canvas)
    frame_fill = (18, 16, 14) if dark_theme else (26, 22, 18)
    # Outer shell
    d.rounded_rectangle(
        [FRAME_X, FRAME_Y, FRAME_X + FRAME_W, FRAME_Y + FRAME_H],
        radius=FRAME_R, fill=frame_fill
    )
    # Screen cutout (filled with white, screenshot composited on top)
    d.rounded_rectangle(
        [SCREEN_X, SCREEN_Y, SCREEN_X + SCREEN_W, SCREEN_Y + SCREEN_H],
        radius=FRAME_R - BEZEL + 4, fill=(255, 255, 255)
    )
    # Front camera dot (top center of bezel)
    cam_cx = FRAME_X + FRAME_W // 2
    cam_cy = FRAME_Y + BEZEL // 2
    d.ellipse(
        [cam_cx - CAM_R, cam_cy - CAM_R, cam_cx + CAM_R, cam_cy + CAM_R],
        fill=(8, 7, 6)
    )


def paste_screenshot(canvas, shot_path, dark_theme=False):
    shot = Image.open(shot_path).convert("RGBA")
    sw, sh = shot.size
    # Scale to fill screen area, then crop
    scale = max(SCREEN_W / sw, SCREEN_H / sh)
    new_w = int(sw * scale)
    new_h = int(sh * scale)
    shot = shot.resize((new_w, new_h), Image.LANCZOS)
    # Center-crop
    cx = (new_w - SCREEN_W) // 2
    cy = (new_h - SCREEN_H) // 2
    shot = shot.crop((cx, cy, cx + SCREEN_W, cy + SCREEN_H))
    # Apply rounded corners to screenshot
    mask = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    mask_d = ImageDraw.Draw(mask)
    mask_d.rounded_rectangle([0, 0, SCREEN_W, SCREEN_H], radius=FRAME_R - BEZEL + 4, fill=255)
    canvas.paste(shot, (SCREEN_X, SCREEN_Y), mask)


def draw_text_centered(draw, text, font, y, color, canvas_w, line_spacing=1.25):
    lines = text.split("\n")
    line_h = font.size
    block_h = len(lines) * line_h + (len(lines) - 1) * int(line_h * (line_spacing - 1))
    cur_y = y - block_h // 2
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        w = bbox[2] - bbox[0]
        x = (canvas_w - w) // 2
        draw.text((x, cur_y), line, font=font, fill=color)
        cur_y += int(line_h * line_spacing)


# Each slide: (raw_filename, headline, subheadline, dark_theme)
SLIDES = [
    ("01-read.png",     "Read it.\nDon't memorize it.",    "Smooth, steady scrolling at your pace.",       False),
    ("02-voice.png",    "Hands-free\nVoice-Follow",         "The script moves as you speak.",               False),
    ("03-karaoke.png",  "Never lose\nyour place",           "Karaoke keeps your line bright.",              True),
    ("04-customize.png","Make every\nword yours",           "Six themes, seven fonts, any color.",          False),
    ("05-home.png",     "Light or dark,\nyour choice",      "Six calm themes for any time of day.",         True),
    ("06-editor.png",   "Any script\nin seconds",           "Write, paste, or start from a template.",      False),
    ("07-pro.png",      "Unlock it all,\nonce",             "No subscription. Yours forever.",              True),
]


def make_slide(raw_filename, headline, subheadline, dark):
    bg = DARK_BG if dark else WARM_BG
    txt = LIGHT_TEXT if dark else WARM_TEXT
    sub = SUBTEXT_DARK if dark else SUBTEXT_WARM

    canvas = Image.new("RGBA", (CW, CH), bg + (255,))
    d = ImageDraw.Draw(canvas)

    # Headline: vertically centered in the top zone (0 to FRAME_Y)
    headline_zone_center = FRAME_Y // 2 - 20
    draw_text_centered(d, headline, HEADLINE_FONT, headline_zone_center, txt, CW)

    # Subheadline: just below headline
    # Measure headline block height first
    lines = headline.split("\n")
    hl_block_h = len(lines) * HEADLINE_FONT.size + (len(lines)-1) * int(HEADLINE_FONT.size * 0.25)
    sub_y = headline_zone_center + hl_block_h // 2 + 36
    draw_text_centered(d, subheadline, SUBHEAD_FONT, sub_y + SUBHEAD_FONT.size // 2, sub, CW)

    draw_ipad_frame(canvas, dark)

    shot_path = os.path.join(RAW, raw_filename)
    paste_screenshot(canvas, shot_path, dark)

    out_path = os.path.join(OUT, raw_filename)
    canvas.convert("RGB").save(out_path, "PNG", optimize=False)
    print(f"  Saved {out_path}")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for args in SLIDES:
        print(f"Making {args[0]}...")
        make_slide(*args)
    print("Done.")
