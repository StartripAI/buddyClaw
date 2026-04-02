#!/usr/bin/env python3
"""
V3 sprite processor for rework batch.
Handles the 8 species from REWORK_PROMPTS.md.

Key features:
- Content-aware frame extraction (handles 2x2, 4x1, 4x3 grids)  
- Auto-crops to character bounding box
- Scales character to fill ~75% of 256x256 frame
- Baseline alignment (bottom 10% margin)
- Aggressive background removal (grey/white/checkerboard)
- Removes floor lines
"""

import os
from typing import List, Sequence, Tuple

import numpy as np
from PIL import Image

BRAIN_DIR = "/Users/star/.gemini/antigravity/brain/e4bba1f9-148e-4887-8214-a3a149c67494"
AUTHOR_DIR = "/Users/star/BuddyClaw/Sources/DesktopBuddy/Resources/Spritesheets"
OUTPUT_DIR = "/Users/star/BuddyClaw/Sources/DesktopBuddy/Resources/RuntimeSprites"

# V3 rework batch
REWORK_MAP = {
    "robot": "robot_v3",
    "penguin": "penguin_v3",
    "rabbit": "rabbit_v3",
    "owl": "owl_v3",
    "ghost": "ghost_v3",
    "mushroom": "mushroom_v3",
    "dragon": "dragon_v3",
    "chonk": "chonk_v3",
}


def find_file(prefix):
    for f in sorted(os.listdir(BRAIN_DIR)):
        if f.startswith(prefix) and f.endswith(".png"):
            return os.path.join(BRAIN_DIR, f)
    return None


def remove_bg(data, tolerance=32):
    """Remove checkerboard/grey/white background."""
    h, w = data.shape[:2]
    corner_size = max(4, min(h, w) // 20)
    
    bg_colors = set()
    for cy, cx in [(0, 0), (0, w - corner_size), (h - corner_size, 0), (h - corner_size, w - corner_size)]:
        corner = data[cy:cy+corner_size, cx:cx+corner_size, :3]
        for y in range(corner.shape[0]):
            for x in range(corner.shape[1]):
                r, g, b = int(corner[y, x, 0]), int(corner[y, x, 1]), int(corner[y, x, 2])
                if abs(r - g) <= 12 and abs(g - b) <= 12:
                    bg_colors.add((r, g, b))
    
    # Add standard greys
    for c in range(120, 256):
        bg_colors.add((c, c, c))
    
    alpha = np.full((h, w), 255, dtype=np.uint8)
    for bg in bg_colors:
        r, g, b = bg
        dist_sq = (
            (data[:, :, 0].astype(np.int32) - r) ** 2 +
            (data[:, :, 1].astype(np.int32) - g) ** 2 +
            (data[:, :, 2].astype(np.int32) - b) ** 2
        )
        alpha[dist_sq < tolerance ** 2] = 0
    
    # Also remove pure black thin horizontal lines (floor/baseline artifacts)
    for y in range(h):
        row = data[y, :, :3]
        black_count = np.sum(np.all(row < 20, axis=1))
        if black_count > w * 0.5:  # More than 50% of row is near-black
            alpha[y, :] = 0
    
    return alpha


def get_content_bbox(alpha):
    rows = np.any(alpha > 0, axis=1)
    cols = np.any(alpha > 0, axis=0)
    if not rows.any():
        return None
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    return (cmin, rmin, cmax + 1, rmax + 1)


def merge_close_bands(bands: Sequence[Tuple[int, int]], gap_tolerance: int = 10) -> List[Tuple[int, int]]:
    if not bands:
        return []
    merged = [bands[0]]
    for start, end in bands[1:]:
        prev_start, prev_end = merged[-1]
        if start - prev_end <= gap_tolerance:
            merged[-1] = (prev_start, end)
        else:
            merged.append((start, end))
    return merged


def find_content_bands(counts: np.ndarray, threshold: int, min_span: int) -> List[Tuple[int, int]]:
    active = counts > threshold
    bands: List[Tuple[int, int]] = []
    start = None
    for idx, has_content in enumerate(active):
        if has_content and start is None:
            start = idx
        elif not has_content and start is not None:
            if idx - start >= min_span:
                bands.append((start, idx))
            start = None
    if start is not None and len(active) - start >= min_span:
        bands.append((start, len(active)))
    return merge_close_bands(bands)


def detect_regions(alpha: np.ndarray) -> List[Tuple[int, int, int, int]]:
    """Detect 4 production frames from square or wide source art."""
    h, w = alpha.shape
    row_counts = np.sum(alpha > 0, axis=1)
    col_counts = np.sum(alpha > 0, axis=0)

    row_threshold = max(8, int(w * 0.015))
    col_threshold = max(8, int(h * 0.015))
    min_row_span = max(24, h // 32)
    min_col_span = max(24, w // 32)

    row_bands = find_content_bands(row_counts, row_threshold, min_row_span)
    col_bands = find_content_bands(col_counts, col_threshold, min_col_span)

    if len(row_bands) == 2 and len(col_bands) == 2:
        print("     → Detected 2x2 grid")
        return [
            (col_bands[0][0], row_bands[0][0], col_bands[0][1], row_bands[0][1]),
            (col_bands[1][0], row_bands[0][0], col_bands[1][1], row_bands[0][1]),
            (col_bands[0][0], row_bands[1][0], col_bands[0][1], row_bands[1][1]),
            (col_bands[1][0], row_bands[1][0], col_bands[1][1], row_bands[1][1]),
        ]

    if len(col_bands) == 4 and len(row_bands) >= 1:
        if len(row_bands) > 1:
            print("     → Detected multi-row strip, taking first content row only")
        row_start, row_end = row_bands[0]
        return [(start, row_start, end, row_end) for start, end in col_bands[:4]]

    # Fallback: equal-width horizontal strip.
    print("     → Falling back to equal-width 4x1 extraction")
    qw = w // 4
    return [(i * qw, 0, (i + 1) * qw, h) for i in range(4)]


def extract_4_frames(img_rgba, data_np):
    """Extract exactly 4 frames, handling 4x1, 4xN, and 2x2 layouts."""
    alpha = data_np[:, :, 3]
    regions = detect_regions(alpha)
    return [img_rgba.crop(region) for region in regions]


def normalize_frame(frame_rgba, target_fill=0.75, target_size=256):
    """Crop to content, scale to fill frame, center + baseline align."""
    data = np.array(frame_rgba)
    alpha = data[:, :, 3]
    bbox = get_content_bbox(alpha)
    
    if bbox is None:
        return Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    
    x1, y1, x2, y2 = bbox
    content = frame_rgba.crop((x1, y1, x2, y2))
    cw, ch = content.size
    
    if cw == 0 or ch == 0:
        return Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    
    target_h = int(target_size * target_fill)
    scale = target_h / ch
    max_w = int(target_size * 0.85)
    if cw * scale > max_w:
        scale = max_w / cw
    
    new_w = max(1, int(cw * scale))
    new_h = max(1, int(ch * scale))
    
    content_resized = content.resize((new_w, new_h), Image.NEAREST)
    
    output = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    paste_x = (target_size - new_w) // 2
    bottom_margin = int(target_size * 0.10)
    paste_y = max(0, target_size - new_h - bottom_margin)
    
    output.paste(content_resized, (paste_x, paste_y), content_resized)
    return output


def process_species(species, prefix):
    src = find_file(prefix)
    if not src:
        print(f"  ❌ {species}: source not found")
        return False
    
    img = Image.open(src).convert("RGBA")
    data = np.array(img)
    print(f"  📐 {species}: source {img.size[0]}x{img.size[1]}")
    
    # Remove background
    alpha = remove_bg(data[:, :, :3])
    data[:, :, 3] = alpha
    img_clean = Image.fromarray(data)
    
    # Extract 4 frames
    frames = extract_4_frames(img_clean, data)
    
    # Normalize each frame
    normalized = [normalize_frame(f) for f in frames]
    
    # Assemble 4x1 strip
    output = Image.new("RGBA", (1024, 256), (0, 0, 0, 0))
    for i, frame in enumerate(normalized):
        output.paste(frame, (i * 256, 0), frame)
    
    # Save
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    dest = os.path.join(OUTPUT_DIR, f"{species}.png")
    output.save(dest, "PNG")
    
    out_data = np.array(output)
    trans_pct = np.sum(out_data[:, :, 3] == 0) / out_data[:, :, 3].size * 100
    print(f"  ✅ {species}: saved 1024x256, {trans_pct:.0f}% transparent")
    return True


def main():
    print("🎮 BuddyClaw V3 Rework Processor")
    print(f"   Processing {len(REWORK_MAP)} species from REWORK_PROMPTS.md")
    print()
    
    success = 0
    for species, prefix in REWORK_MAP.items():
        if process_species(species, prefix):
            success += 1
    
    print(f"\n📊 {success}/{len(REWORK_MAP)} processed")
    
    # Final validation of ALL 18
    print("\n🔍 Final check (all 18):")
    all_species = [
        "axolotl", "blob", "cactus", "capybara", "cat", "chonk",
        "dragon", "duck", "ghost", "goose", "mushroom", "octopus",
        "owl", "penguin", "rabbit", "robot", "snail", "turtle",
    ]
    ok = 0
    for sp in all_species:
        path = os.path.join(OUTPUT_DIR, f"{sp}.png")
        if not os.path.exists(path):
            print(f"  ❌ {sp}: MISSING")
            continue
        img = Image.open(path)
        d = np.array(img)
        sz_ok = img.size == (1024, 256)
        mode_ok = img.mode == "RGBA"
        trans = np.sum(d[:, :, 3] == 0) / d[:, :, 3].size * 100
        trans_ok = trans > 30
        
        if sz_ok and mode_ok and trans_ok:
            print(f"  ✅ {sp:12s}  {trans:.0f}% transparent")
            ok += 1
        else:
            issues = []
            if not sz_ok: issues.append(f"size={img.size}")
            if not mode_ok: issues.append(f"mode={img.mode}")
            if not trans_ok: issues.append(f"only {trans:.0f}% transparent")
            print(f"  ⚠️  {sp:12s}  {' | '.join(issues)}")
    
    print(f"\n📊 Final: {ok}/18 pass")


if __name__ == "__main__":
    main()
