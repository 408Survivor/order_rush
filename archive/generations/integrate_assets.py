#!/usr/bin/env python3
"""美术二期 #63：把 archive 里的 clean 素材按目标尺寸集成进 assets/art/

策略：道具 PNG 缩放到旧 SVG 的「保留维度」像素尺寸 → 代码里既有 scale 全部不用动；
角色保持全分辨率 → 在 tscn/脚本里改 scale（另行编辑）。
"""
from PIL import Image
from pathlib import Path

ROOT = Path("/Users/liutongqing/Downloads/GameDev/order_rush")
G = ROOT / "archive/generations"


def tight(im: Image.Image, pad: int = 8) -> Image.Image:
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        return im
    x0 = max(0, bbox[0] - pad); y0 = max(0, bbox[1] - pad)
    x1 = min(im.width, bbox[2] + pad); y1 = min(im.height, bbox[3] + pad)
    return im.crop((x0, y0, x1, y1))


def fit(im: Image.Image, w: int = 0, h: int = 0) -> Image.Image:
    if w:
        h = round(im.height * w / im.width)
    else:
        w = round(im.width * h / im.height)
    return im.resize((w, h), Image.LANCZOS)


# (源 clean 图, 目标 assets 路径, 保留宽 w / 高 h)
JOBS = [
    # ---- 批次 015 厨房一线 ----
    (G/"015-kitchen-line/counter_bar_v1_clean.png",     "assets/art/props/counter_bar.png",     {"w": 480}),
    (G/"015-kitchen-line/work_table_v2_clean.png",      "assets/art/props/work_table.png",      {"w": 900}),
    (G/"015-kitchen-line/fridge_cabinet_v1_clean.png",  "assets/art/props/fridge_cabinet.png",  {"w": 380}),
    (G/"015-kitchen-line/freezer_v1_clean.png",         "assets/art/props/freezer.png",         {"w": 200}),
    (G/"015-kitchen-line/microwave_v1_clean.png",       "assets/art/props/microwave.png",       {"w": 220}),
    (G/"015-kitchen-line/cashier_v1_clean.png",         "assets/art/props/cashier.png",         {"w": 140}),
    (G/"015-kitchen-line/takeout_window_v1_clean.png",  "assets/art/props/takeout_window.png",  {"w": 200}),
    # ---- 批次 016 环境 ----
    (G/"016-environment/wall_top_v2_clean.png",         "assets/art/props/wall_top.png",        {"w": 480}),
    (G/"016-environment/wall_side_v2_clean.png",        "assets/art/props/wall_side.png",       {"h": 480}),
    (G/"016-environment/door_v1_clean.png",             "assets/art/props/door.png",            {"h": 120}),
    (G/"016-environment/table_v2_clean.png",            "assets/art/props/table.png",           {"w": 160}),
    (G/"016-environment/chair_v1_clean.png",            "assets/art/props/chair.png",           {"w": 100}),
    (G/"016-environment/rug_v1_clean.png",              "assets/art/props/rug.png",             {"w": 832}),
    (G/"016-environment/plant_v1_clean.png",            "assets/art/props/plant.png",           {"h": 140}),
    (G/"016-environment/trash_bin_v1_clean.png",        "assets/art/props/trash_bin.png",       {"h": 120}),
    (G/"016-environment/floor_mat_v1_clean.png",        "assets/art/props/floor_mat.png",       {"w": 180}),
    (G/"016-environment/crate_v1_clean.png",            "assets/art/props/crate.png",           {"w": 140}),
    (G/"016-environment/crate_v1_clean.png",            "assets/art/props/crate_stack.png",     {"w": 200}),
    (G/"016-environment/floor_tile_v1_clean.png",       "assets/art/environment/floor_tile.png", {"w": 1024}),
    # ---- 批次 017 料理包/成品菜（128 = 旧 SVG 原生尺寸，scale 不动）----
    (G/"017-characters-dishes/meal_pack_kungpao_v1_clean.png", "assets/art/items/meal_pack_kungpao.png", {"w": 128}),
    (G/"017-characters-dishes/meal_pack_yuxiang_v1_clean.png", "assets/art/items/meal_pack_yuxiang.png", {"w": 128}),
    (G/"017-characters-dishes/meal_pack_mapo_v1_clean.png",    "assets/art/items/meal_pack_mapo.png",    {"w": 128}),
    (G/"017-characters-dishes/dish_kungpao_v1_clean.png",      "assets/art/items/dish_kungpao_plated.png", {"w": 128}),
    (G/"017-characters-dishes/dish_yuxiang_v1_clean.png",      "assets/art/items/dish_yuxiang_plated.png", {"w": 128}),
    (G/"017-characters-dishes/dish_mapo_v1_clean.png",         "assets/art/items/dish_mapo_plated.png",    {"w": 128}),
    # ---- 角色：全分辨率（scale 在 tscn/脚本里改）----
    (G/"014-chef_overhead_anchor/chef_overhead_v1_clean.png",  "assets/art/characters/player_chef_idle.png", {}),
    (G/"017-characters-dishes/customer_v1_clean.png",          "assets/art/characters/customer_office_waiting.png", {}),
    (G/"017-characters-dishes/rider_v1_clean.png",             "assets/art/characters/rider.png", {}),
]

for src, dst_rel, dim in JOBS:
    im = Image.open(src).convert("RGBA")
    im = tight(im)
    if dim:
        im = fit(im, **dim)
    dst = ROOT / dst_rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    print(f"{dst_rel:55s} {im.width}x{im.height}")
