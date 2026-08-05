#!/usr/bin/env python3
"""AI 生成素材批量后处理（美术二期 #63）

用法: python3 postprocess_asset.py 输入.png 输出.png
步骤:
  1. 擦除左下角 "AI生成" 水印（仅擦半透明/近白像素，不伤深棕描边主体）
  2. 按 alpha 包围盒裁边，留 16px 边距
  3. 居中放置到正方形画布（不缩放）
"""
import sys
import numpy as np
from PIL import Image


def main(src: str, dst: str) -> None:
    im = Image.open(src).convert("RGBA")
    a = np.array(im)
    h, w = a.shape[:2]

    # 1. 水印区：左下角（实测水印位于 x<26% w, y>91% h 的透明区）
    y0, x1 = int(h * 0.90), int(w * 0.28)
    region = a[y0:, :x1]
    alpha = region[..., 3].astype(int)
    rgb_min = region[..., :3].min(axis=2).astype(int)
    # 水印特征：半透明白字。只擦 alpha<250 或 近白(min>200) 的像素
    mask = (alpha > 0) & ((alpha < 250) | (rgb_min > 200))
    erased = int(mask.sum())
    region[..., 3][mask] = 0
    a[y0:, :x1] = region

    # 2. alpha 包围盒裁边
    ys, xs = np.where(a[..., 3] > 8)
    if len(xs) == 0:
        print("!! 全透明，未处理:", src)
        return
    pad = 16
    x_lo, x_hi = max(0, xs.min() - pad), min(w, xs.max() + pad + 1)
    y_lo, y_hi = max(0, ys.min() - pad), min(h, ys.max() + pad + 1)
    a = a[y_lo:y_hi, x_lo:x_hi]

    # 3. 居中正方形画布
    ch, cw = a.shape[:2]
    side = max(cw, ch)
    canvas = np.zeros((side, side, 4), dtype=np.uint8)
    oy, ox = (side - ch) // 2, (side - cw) // 2
    canvas[oy:oy + ch, ox:ox + cw] = a

    Image.fromarray(canvas).save(dst)
    print(f"OK {dst}  裁边 {cw}x{ch} -> 画布 {side}x{side}  擦除水印像素 {erased}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法: python3 postprocess_asset.py 输入.png 输出.png")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
