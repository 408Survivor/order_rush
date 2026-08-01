#!/usr/bin/env python3
"""
grabcut_bg.py — GrabCut 交互式前景分割去底（适合白主体+白背景，亮度阈值法失效的场景）

原理：OpenCV GrabCut 用颜色模型 + 边界梯度区分前景/背景，
白色盘子（前景）与白色背景即使亮度接近，也能靠盘沿的轮廓梯度分离。

用法：
  python3 grabcut_bg.py <input.png> [output.png] [--rect x0,y0,x1,y1] [--feather N]

参数：
  --rect       前景初始化矩形（相对坐标 0-1），默认 "0.15,0.2,0.85,0.8"
  --feather N  边缘羽化层数（默认 1，GrabCut 边界已较平滑）
  --preview    输出对比预览图
"""
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

GC_BGD = 0
GC_FGD = 1
GC_PR_BGD = 2
GC_PR_FGD = 3


def grabcut_alpha(img: Image.Image, rect: tuple) -> Image.Image:
    """GrabCut 分割，返回 RGBA（背景 alpha=0）。"""
    rgb = img.convert("RGB")
    arr = np.array(rgb)
    h, w = arr.shape[:2]
    x0, y0, x1, y1 = [int(v * d) for v, d in zip(rect, (w, h, w, h))]

    mask = np.zeros((h, w), np.uint8)
    mask[:, :] = GC_PR_BGD
    mask[y0:y1, x0:x1] = GC_PR_FGD
    # 边缘一圈确定为背景
    edge = 4
    mask[:edge, :] = GC_BGD
    mask[-edge:, :] = GC_BGD
    mask[:, :edge] = GC_BGD
    mask[:, -edge:] = GC_BGD

    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(arr, mask, None, bgd, fgd, 5, cv2.GC_INIT_WITH_MASK)

    alpha = np.where((mask == GC_FGD) | (mask == GC_PR_FGD), 255, 0).astype(np.uint8)
    rgba = img.convert("RGBA")
    arr_rgba = np.array(rgba)
    arr_rgba[:, :, 3] = alpha
    return Image.fromarray(arr_rgba)


def feather_alpha(rgba: Image.Image, layers: int = 1) -> Image.Image:
    """对 alpha 边界做平滑（GrabCut 结果通常已平滑，少量羽化即可）。"""
    if layers <= 0:
        return rgba
    arr = np.array(rgba)
    a = arr[:, :, 3]
    # 对边界 alpha 做高斯模糊并二值化阈值平滑：保留 128 以上
    a_blur = cv2.GaussianBlur(a, (5, 5), 0)
    arr[:, :, 3] = np.where(a > 0, np.maximum(a, a_blur), 0)
    return Image.fromarray(arr)


def make_preview(original: Image.Image, cleaned: Image.Image, out_path: str, scale: int = 8) -> None:
    w, h = original.size
    tw, th = w // scale, h // scale
    orig = original.convert("RGB").resize((tw, th), Image.LANCZOS)
    clean = cleaned.resize((tw, th), Image.LANCZOS)
    checker = Image.new("RGB", (tw, th), (255, 255, 255))
    d = ImageDraw.Draw(checker)
    cell = 16
    for cy in range(0, th, cell):
        for cx in range(0, tw, cell):
            if (cx // cell + cy // cell) % 2 == 0:
                d.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], fill=(200, 200, 200))
    checker.paste(clean, (0, 0), clean)
    dark = Image.new("RGB", (tw, th), (60, 60, 70))
    dark.paste(clean, (0, 0), clean)
    canvas = Image.new("RGB", (tw * 3 + 8, th), (40, 40, 40))
    canvas.paste(orig, (0, 0))
    canvas.paste(checker, (tw + 4, 0))
    canvas.paste(dark, (tw * 2 + 8, 0))
    canvas.save(out_path)
    print(f"预览已保存: {out_path}")


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = set(a for a in sys.argv[1:] if a.startswith("--"))
    rect = (0.15, 0.2, 0.85, 0.8)
    feather = 1
    argv = sys.argv[1:]
    for i, a in enumerate(argv):
        if a == "--rect" and i + 1 < len(argv):
            rect = tuple(float(v) for v in argv[i + 1].split(","))
        if a == "--feather" and i + 1 < len(argv):
            feather = int(argv[i + 1])

    if not args:
        print(__doc__)
        sys.exit(1)
    src, dst = args[0], args[1] if len(args) > 1 else args[0]
    img = Image.open(src)
    cleaned = grabcut_alpha(img, rect)
    cleaned = feather_alpha(cleaned, feather)
    cleaned.save(dst)
    print(f"完成: {src} -> {dst} (rect={rect}, feather={feather})")
    if "--preview" in flags:
        make_preview(img, cleaned, dst.rsplit(".", 1)[0] + "_preview.png")


if __name__ == "__main__":
    main()
