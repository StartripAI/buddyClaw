#!/usr/bin/env python3
import os
from collections import deque

import numpy as np
from PIL import Image
from PIL import ImageFilter

BRAIN_DIR = "/Users/star/.gemini/antigravity/brain/e4bba1f9-148e-4887-8214-a3a149c67494"
SHEET_DIR = "/Users/star/BuddyClaw/Sources/DesktopBuddy/Resources/ClawSprites"

SPECIES = [
    "axolotl", "blob", "cactus", "capybara", "cat", "chonk",
    "dragon", "duck", "ghost", "goose", "mushroom", "octopus",
    "owl", "penguin", "rabbit", "robot", "snail", "turtle",
]


def find_file(species):
    prefix_v2 = f"{species}_claw_v2_"
    for filename in sorted(os.listdir(BRAIN_DIR), reverse=True):
        if filename.startswith(prefix_v2) and filename.endswith(".png"):
            return os.path.join(BRAIN_DIR, filename)

    prefix = f"{species}_claw_"
    for filename in sorted(os.listdir(BRAIN_DIR), reverse=True):
        if filename.startswith(prefix) and filename.endswith(".png"):
            return os.path.join(BRAIN_DIR, filename)
    return None


def build_foreground_mask(rgb_data):
    max_channel = rgb_data.max(axis=2)
    min_channel = rgb_data.min(axis=2)
    saturation = max_channel - min_channel

    # The generated sheets use gray checkerboards. High-saturation pixels isolate the
    # mascot cleanly while leaving the checkerboard and robot text labels behind.
    colorful_mask = saturation > 20
    mask_image = Image.fromarray((colorful_mask.astype(np.uint8) * 255), mode="L")

    # Expand slightly so outlines remain attached to the colorful fill.
    expanded_mask = mask_image.filter(ImageFilter.MaxFilter(5))
    return np.array(expanded_mask) > 0


def connected_components(mask, min_area=300):
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    components = []

    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue

            queue = deque([(x, y)])
            seen[y, x] = True
            xs = []
            ys = []

            while queue:
                cx, cy = queue.popleft()
                xs.append(cx)
                ys.append(cy)

                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((nx, ny))

            area = len(xs)
            if area < min_area:
                continue

            x1 = min(xs)
            y1 = min(ys)
            x2 = max(xs) + 1
            y2 = max(ys) + 1
            components.append({
                "bbox": (x1, y1, x2, y2),
                "area": area,
                "center_x": (x1 + x2) / 2,
                "center_y": (y1 + y2) / 2,
                "width": x2 - x1,
                "height": y2 - y1,
            })

    return components


def significant_components(components):
    if not components:
        return []

    max_area = max(component["area"] for component in components)
    threshold = max_area * 0.75
    kept = [component for component in components if component["area"] >= threshold]
    return kept if kept else components


def cluster_rows(components):
    if not components:
        return []

    ordered = sorted(components, key=lambda component: component["center_y"])
    rows = [[ordered[0]]]

    for component in ordered[1:]:
        current_row = rows[-1]
        row_center = sum(item["center_y"] for item in current_row) / len(current_row)
        reference_height = max(item["height"] for item in current_row + [component])
        tolerance = max(48, int(reference_height * 0.55))

        if abs(component["center_y"] - row_center) <= tolerance:
            current_row.append(component)
        else:
            rows.append([component])

    for row in rows:
        row.sort(key=lambda component: component["center_x"])

    return rows


def choose_frame_components(mask):
    components = connected_components(mask)
    if not components:
        return []

    kept = significant_components(components)
    rows = cluster_rows(kept)

    full_rows = [row for row in rows if len(row) >= 4]
    if full_rows:
        best_row = max(full_rows, key=lambda row: sum(component["area"] for component in row[:4]))
        return best_row[:4]

    if len(kept) == 4:
        flattened = []
        for row in rows:
            flattened.extend(row)
        return flattened[:4]

    if len(kept) > 4:
        top_four = sorted(kept, key=lambda component: component["area"], reverse=True)[:4]
        rows = cluster_rows(top_four)
        flattened = []
        for row in rows:
            flattened.extend(row)
        return flattened[:4]

    return sorted(kept, key=lambda component: (component["center_y"], component["center_x"]))


def get_content_bbox(alpha):
    rows = np.any(alpha > 0, axis=1)
    cols = np.any(alpha > 0, axis=0)
    if not rows.any():
        return None
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    return (cmin, rmin, cmax + 1, rmax + 1)


def extract_4_frames(img_rgba, mask):
    components = choose_frame_components(mask)
    if len(components) != 4:
        raise RuntimeError(f"Unable to resolve 4 frames, found {len(components)} candidate groups")

    frames = []
    for component in components:
        x1, y1, x2, y2 = component["bbox"]
        padding = 10
        crop_box = (
            max(0, x1 - padding),
            max(0, y1 - padding),
            min(img_rgba.width, x2 + padding),
            min(img_rgba.height, y2 + padding),
        )
        frames.append(img_rgba.crop(crop_box))
    return frames


def normalize_frame(frame_rgba, target_fill=0.75, target_size=256):
    data = np.array(frame_rgba)
    alpha = data[:, :, 3]
    bbox = get_content_bbox(alpha)
    if bbox is None:
        return Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))

    x1, y1, x2, y2 = bbox
    content = frame_rgba.crop((x1, y1, x2, y2))
    content_width, content_height = content.size
    if content_width == 0 or content_height == 0:
        return Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))

    scale = int(target_size * target_fill) / content_height
    max_width = int(target_size * 0.85)
    if content_width * scale > max_width:
        scale = max_width / content_width

    new_width = max(1, int(content_width * scale))
    new_height = max(1, int(content_height * scale))
    content_resized = content.resize((new_width, new_height), Image.NEAREST)

    output = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    paste_x = (target_size - new_width) // 2
    paste_y = max(0, target_size - new_height - int(target_size * 0.10))
    output.paste(content_resized, (paste_x, paste_y), content_resized)
    return output


def process_species(species):
    print(f"[{species}] Finding file...")
    src = find_file(species)
    if not src:
        print(f"  ❌ {species}: source not found")
        return False

    print(f"[{species}] Found: {src}. Loading image...")
    img = Image.open(src).convert("RGBA")
    data = np.array(img)

    print(f"[{species}] Building foreground mask...")
    mask = build_foreground_mask(data[:, :, :3])
    data[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
    img_clean = Image.fromarray(data)

    print(f"[{species}] Extracting frames...")
    frames = extract_4_frames(img_clean, mask)

    print(f"[{species}] Normalizing frames...")
    normalized = [normalize_frame(frame) for frame in frames]

    print(f"[{species}] Assembling...")
    output = Image.new("RGBA", (1024, 256), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        output.paste(frame, (index * 256, 0), frame)

    dest = os.path.join(SHEET_DIR, f"{species}.png")
    output.save(dest, "PNG")

    out_data = np.array(output)
    transparent_ratio = np.sum(out_data[:, :, 3] == 0) / out_data[:, :, 3].size * 100
    print(f"  ✅ {species}: saved 1024x256, {transparent_ratio:.0f}% transparent")
    return True


if __name__ == "__main__":
    print("🤖 Processing Claw Style Sprites...")
    success = 0
    for species in SPECIES:
        if process_species(species):
            success += 1
    print(f"\n📊 {success}/18 processed successfully.")
