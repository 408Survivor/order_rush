#!/usr/bin/env python3
"""
remove_white_bg.py — 白底素材去底工具（连通域法）

原理：从图片四边做 BFS 泛洪，只删除"与边缘连通的近白像素"，
角色/物品内部的白色（如厨师服）与边缘不连通，得以保留。

用法：
  python3 remove_white_bg.py <input.png> [output.png] [--threshold 245] [--preview]

参数：
  --threshold T   近白判定阈值（RGB 均 > T，默认 245）
  --feather N     边界羽化层数（默认 0 不羽化；处理背景渐变带噪点用 3）
  --preview       同时输出一张对比预览图（原图 | 去底+棋盘底）

批次：009-bg-removal（2026-08-01）
素材：player_chef_idle / customer_office_waiting / chef_front_view_v1/v2
      meal_kungpao / dish_kungpao_plated / microwave_idle（均为 RGB 白底，无 alpha）
"""
import sys
from collections import deque

from PIL import Image, ImageDraw


def remove_white_bg(img: Image.Image, threshold: int = 245) -> Image.Image:
    """删除与边缘连通的近白像素，返回 RGBA 图。"""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    visited = bytearray(w * h)  # 0=未访问, 1=已入队

    def is_bg(x: int, y: int) -> bool:
        p = px[x, y]
        return p[0] > threshold and p[1] > threshold and p[2] > threshold

    # BFS 从四边所有近白像素出发
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(x, y):
                q.append((x, y))
                visited[y * w + x] = 1
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(x, y):
                q.append((x, y))
                visited[y * w + x] = 1

    while q:
        x, y = q.popleft()
        px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)  # 置透明
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx]:
                visited[ny * w + nx] = 1
                if is_bg(nx, ny):
                    q.append((nx, ny))
    return rgba


def remove_white_bg_protected(img: Image.Image, threshold: int = 225,
                              protect_threshold: int = 245) -> Image.Image:
    """双阈值保护版去底：白色主体（如白盘子）不被误删。

    1. 从中心 flood fill（protect_threshold）定位主体亮块 → 保护
    2. 从边缘 flood fill（threshold）删背景，但跳过保护块
    适合"白色主体 + 白色背景"（背景渐变带低于 protect_threshold 时盘沿可自然隔开）。
    """
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    def is_bright(x: int, y: int, t: int) -> bool:
        p = px[x, y]
        return p[0] > t and p[1] > t and p[2] > t

    # ---- 1. 定位保护块：先做 245 边缘泛洪（盘子与背景在此阈值不连通，盘子保留），
    #        剩余不透明亮像素的连通块即主体（如白盘子），标记为保护 ----
    protected = bytearray(w * h)
    visited_hi = bytearray(w * h)

    def flood_from_edges(t: int, visited: bytearray, skip: bytearray = None) -> None:
        q = deque()
        for x in range(w):
            for y in (0, h - 1):
                if (skip is None or not skip[y * w + x]) and is_bright(x, y, t):
                    q.append((x, y))
                    visited[y * w + x] = 1
        for y in range(h):
            for x in (0, w - 1):
                if (skip is None or not skip[y * w + x]) and is_bright(x, y, t):
                    q.append((x, y))
                    visited[y * w + x] = 1
        while q:
            x, y = q.popleft()
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx] \
                        and (skip is None or not skip[ny * w + nx]):
                    visited[ny * w + nx] = 1
                    if is_bright(nx, ny, t):
                        q.append((nx, ny))

    flood_from_edges(protect_threshold, visited_hi)
    # 剩余 >protect_threshold 的像素连通块 = 主体亮块（全部保护）
    for y in range(h):
        for x in range(w):
            if not visited_hi[y * w + x] and is_bright(x, y, protect_threshold):
                protected[y * w + x] = 1
    print(f"保护块大小: {sum(protected)} px ({100 * sum(protected) / (w * h):.1f}% 图面)")

    # ---- 2. 低阈值边缘泛洪删背景（跳过保护块） ----
    visited = bytearray(w * h)
    flood_from_edges(threshold, visited, skip=protected)
    for y in range(h):
        for x in range(w):
            if visited[y * w + x]:
                px[x, y] = (px[x, y][0], px[x, y][1], px[x, y][2], 0)
    return rgba


def feather_edges(rgba: Image.Image, dark_min: int = 200, bright_min: int = 240,
                  layers: int = 3) -> Image.Image:
    """边界羽化：邻接透明区的像素按亮度渐隐，消除背景渐变带残留（噪点/毛边）。

    亮度映射：min(rgb) <= dark_min → 保持不透明；>= bright_min → 全透明；中间线性。
    向主体内部扩散 layers 层。
    """
    w, h = rgba.size
    px = rgba.load()
    span = bright_min - dark_min

    for _ in range(layers):
        changed = False
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if p[3] == 0:
                    continue
                adj_trans = False
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        adj_trans = True
                        break
                if not adj_trans:
                    continue
                m = min(p[0], p[1], p[2])
                if m >= bright_min:
                    new_a = 0
                elif m <= dark_min:
                    new_a = 255
                else:
                    new_a = int(255 * (m - dark_min) / span)
                if new_a < p[3]:
                    px[x, y] = (p[0], p[1], p[2], new_a)
                    changed = True
        if not changed:
            break
    return rgba


def make_preview(original: Image.Image, cleaned: Image.Image, out_path: str, scale: int = 8) -> None:
    """生成对比预览：原图 | 去底图（棋盘透明底）| 去底图（深色底）。"""
    w, h = original.size
    tw = w // scale
    th = h // scale
    orig = original.convert("RGB").resize((tw, th), Image.LANCZOS)
    clean = cleaned.resize((tw, th), Image.LANCZOS)

    # 棋盘透明底
    checker = Image.new("RGB", (tw, th), (255, 255, 255))
    d = ImageDraw.Draw(checker)
    cell = 16
    for cy in range(0, th, cell):
        for cx in range(0, tw, cell):
            if (cx // cell + cy // cell) % 2 == 0:
                d.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], fill=(200, 200, 200))
    checker.paste(clean, (0, 0), clean)

    # 深色底
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
    threshold = 245
    for i, a in enumerate(sys.argv[1:]):
        if a == "--threshold" and i + 2 < len(sys.argv) + 1:
            threshold = int(sys.argv[i + 2])

    if not args:
        print(__doc__)
        sys.exit(1)
    src = args[0]
    dst = args[1] if len(args) > 1 else src

    img = Image.open(src)
    cleaned = remove_white_bg(img, threshold)
    feather_layers = 0
    for i, a in enumerate(sys.argv[1:]):
        if a == "--feather" and i + 2 < len(sys.argv) + 1:
            feather_layers = int(sys.argv[i + 2])
    if feather_layers > 0:
        cleaned = feather_edges(cleaned, layers=feather_layers)
    cleaned.save(dst)
    print(f"完成: {src} -> {dst} (阈值 {threshold}, 羽化 {feather_layers} 层)")

    if "--preview" in flags:
        preview_path = dst.rsplit(".", 1)[0] + "_preview.png"
        make_preview(img, cleaned, preview_path)


if __name__ == "__main__":
    main()
