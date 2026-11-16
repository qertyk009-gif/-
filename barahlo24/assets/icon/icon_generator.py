#!/usr/bin/env python3
"""
Генератор PNG-иконок для «Барахолка24» из программного описания (Pillow).

Не требует cairosvg / внешних конвертеров SVG — рисует ту же композицию
(кошелёк + монета + молоток) средствами Pillow напрямую, чтобы скрипт
работал на любой машине с Python3 + Pillow без доп. системных пакетов.

Генерирует:
  icon_192.png              - иконка 192x192 (mdpi general / launcher)
  icon_512.png              - иконка 512x512 (project icon / store)
  icon_adaptive_fg_432.png  - adaptive icon foreground 432x432 (с прозрачным фоном)
  icon_adaptive_bg_432.png  - adaptive icon background 432x432 (сплошной цвет)

Запуск:
  python3 assets/icon/icon_generator.py
"""

from PIL import Image, ImageDraw
import math
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

COL_BG_TOP = (27, 42, 58, 255)
COL_BG_BOTTOM = (12, 22, 32, 255)
COL_WALLET = (46, 74, 99, 255)
COL_WALLET_FLAP = (58, 92, 121, 255)
COL_WALLET_BORDER = (22, 34, 46, 255)
COL_COIN_TOP = (255, 215, 106, 255)
COL_COIN_BOTTOM = (232, 169, 58, 255)
COL_COIN_BORDER = (138, 90, 20, 255)
COL_HAMMER_HEAD_TOP = (159, 180, 196, 255)
COL_HAMMER_HEAD_BOTTOM = (110, 129, 143, 255)
COL_HAMMER_HANDLE = (138, 90, 51, 255)
COL_HAMMER_HANDLE_BORDER = (92, 58, 32, 255)


def vgradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size, top)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        for x in range(w):
            px[x, y] = (r, g, b, 255)
    return img


def rounded_rect_mask(size, radius):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def draw_wallet_hammer_coin(canvas, draw, scale, ox, oy):
    """Рисует кошелёк+молоток+монету в координатах 512x512, с масштабом scale и смещением (ox,oy)."""
    def pt(x, y):
        return (ox + x * scale, oy + y * scale)

    # Coin stack behind wallet
    sx1, sy1 = pt(124, 378)
    sx2, sy2 = pt(216, 406)
    draw.ellipse([sx1, sy1, sx2, sy2], fill=COL_COIN_BORDER)
    cx1, cy1 = pt(124, 364)
    cx2, cy2 = pt(216, 392)
    draw.ellipse([cx1, cy1, cx2, cy2], fill=COL_COIN_TOP, outline=COL_COIN_BORDER, width=max(1, int(3 * scale)))

    # Wallet body (rounded rect)
    wx1, wy1 = pt(96, 208)
    wx2, wy2 = pt(416, 404)
    radius = int(22 * scale)
    draw.rounded_rectangle([wx1, wy1, wx2, wy2], radius=radius, fill=COL_WALLET,
                            outline=COL_WALLET_BORDER, width=max(2, int(6 * scale)))
    # Wallet top flap strip
    fx1, fy1 = pt(96, 208)
    fx2, fy2 = pt(416, 264)
    draw.rounded_rectangle([fx1, fy1, fx2, fy2], radius=int(14 * scale), fill=COL_WALLET_FLAP)
    # Clasp circle
    ccx, ccy = pt(368, 300)
    r = 16 * scale
    draw.ellipse([ccx - r, ccy - r, ccx + r, ccy + r], fill=COL_COIN_TOP,
                 outline=COL_COIN_BORDER, width=max(1, int(3 * scale)))

    # Hammer (rotated) - approximate with polygon for head + handle
    cxh, cyh = pt(340, 170)
    angle = math.radians(-35)

    def rot(px, py):
        dx, dy = (px - cxh), (py - cyh)
        rx = dx * math.cos(angle) - dy * math.sin(angle)
        ry = dx * math.sin(angle) + dy * math.cos(angle)
        return (cxh + rx, cyh + ry)

    # Head rectangle corners (local coords around hammer center before rotation, in 512-space)
    hx1, hy1, hx2, hy2 = 300, 160, 440, 186
    head_pts = [rot(*pt(hx1, hy1)), rot(*pt(hx2, hy1)), rot(*pt(hx2, hy2)), rot(*pt(hx1, hy2))]
    draw.polygon(head_pts, fill=COL_HAMMER_HEAD_TOP, outline=COL_HAMMER_HEAD_BOTTOM)

    hdx1, hdy1, hdx2, hdy2 = 325, 178, 343, 298
    handle_pts = [rot(*pt(hdx1, hdy1)), rot(*pt(hdx2, hdy1)), rot(*pt(hdx2, hdy2)), rot(*pt(hdx1, hdy2))]
    draw.polygon(handle_pts, fill=COL_HAMMER_HANDLE, outline=COL_HAMMER_HANDLE_BORDER)


def make_main_icon(size):
    img = vgradient((size, size), COL_BG_TOP, COL_BG_BOTTOM)
    radius = int(size * 96 / 512)
    mask = rounded_rect_mask((size, size), radius)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    draw = ImageDraw.Draw(out)
    scale = size / 512
    draw_wallet_hammer_coin(out, draw, scale, 0, 0)
    return out


def make_adaptive_foreground(size):
    # Transparent background, centered content with padding (safe zone ~66% for Android adaptive icons)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    scale = (size / 512) * 0.78
    offset = size * 0.5 - 256 * scale
    draw_wallet_hammer_coin(img, draw, scale, offset, offset)
    return img


def make_adaptive_background(size):
    img = vgradient((size, size), COL_BG_TOP, COL_BG_BOTTOM)
    return img.convert("RGBA")


def main():
    make_main_icon(192).save(os.path.join(OUT_DIR, "icon_192.png"))
    make_main_icon(512).save(os.path.join(OUT_DIR, "icon_512.png"))
    make_adaptive_foreground(432).save(os.path.join(OUT_DIR, "icon_adaptive_fg_432.png"))
    make_adaptive_background(432).save(os.path.join(OUT_DIR, "icon_adaptive_bg_432.png"))
    print("Готово: icon_192.png, icon_512.png, icon_adaptive_fg_432.png, icon_adaptive_bg_432.png")


if __name__ == "__main__":
    main()
