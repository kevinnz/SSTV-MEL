#!/usr/bin/env python3
"""Create a detailed visual comparison showing differences."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

# Project root is one level up from this script
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Accept optional CLI arguments, or use project-relative defaults
decoded_path = sys.argv[1] if len(sys.argv) >= 2 else os.path.join(PROJECT_ROOT, 'output_synced.png')
expected_path = sys.argv[2] if len(sys.argv) >= 3 else os.path.join(PROJECT_ROOT, 'expected', 'Space_Comms_-_2015-04-12_-_0428_UTC_-_80th_Yuri_Gagarin_image_5.jpg')

# Load both images
decoded = Image.open(decoded_path)
expected = Image.open(expected_path)

dec_arr = np.array(decoded.convert('RGB')).astype(float)
exp_arr = np.array(expected.convert('RGB')).astype(float)

# Create a multi-panel comparison
w, h = decoded.size
panel_height = h
total_width = w * 3

comparison = Image.new('RGB', (total_width, panel_height + 100))
draw = ImageDraw.Draw(comparison)

# Panel 1: Decoded
comparison.paste(decoded, (0, 50))
draw.text((10, 10), "Decoded Output", fill='white')

# Panel 2: Expected
comparison.paste(expected, (w, 50))
draw.text((w + 10, 10), "Expected Reference", fill='white')

# Panel 3: Difference (enhanced)
diff = np.abs(dec_arr - exp_arr)
# Enhance the difference to make it visible
diff_enhanced = np.clip(diff * 3, 0, 255).astype(np.uint8)
diff_img = Image.fromarray(diff_enhanced)
comparison.paste(diff_img, (w * 2, 50))
draw.text((w * 2 + 10, 10), "Difference (enhanced 3x)", fill='white')

# Add stats at bottom
stats_y = panel_height + 60
corr = np.corrcoef(dec_arr.flatten(), exp_arr.flatten())[0, 1]
mean_diff = diff.mean()
draw.text((10, stats_y), f"Correlation: {corr:.3f}  |  Mean Diff: {mean_diff:.1f}  |  Expected is JPEG (may have compression artifacts)", fill='white')

detailed_path = os.path.join(PROJECT_ROOT, 'detailed_comparison.png')
comparison.save(detailed_path)
print(f"Saved {detailed_path}")

# Also create a zoomed comparison of a specific region
print("\nCreating zoomed comparison of a specific region...")
zoom_y = 200
zoom_x = 300
zoom_size = 100

dec_crop = decoded.crop((zoom_x, zoom_y, zoom_x + zoom_size, zoom_y + zoom_size))
exp_crop = expected.crop((zoom_x, zoom_y, zoom_x + zoom_size, zoom_y + zoom_size))

# Scale up 4x
dec_zoom = dec_crop.resize((zoom_size * 4, zoom_size * 4), Image.Resampling.NEAREST)
exp_zoom = exp_crop.resize((zoom_size * 4, zoom_size * 4), Image.Resampling.NEAREST)

zoomed = Image.new('RGB', (zoom_size * 8, zoom_size * 4))
zoomed.paste(dec_zoom, (0, 0))
zoomed.paste(exp_zoom, (zoom_size * 4, 0))

zoomed_path = os.path.join(PROJECT_ROOT, 'zoomed_comparison.png')
zoomed.save(zoomed_path)
print(f"Saved {zoomed_path}")

# Check for any repeating pattern issues
print("\n=== Checking for line pair artifacts ===")
# In PD180, we decode 2 lines per frame. Check if odd/even lines differ
dec_even = dec_arr[::2, :, :]  # Lines 0, 2, 4, ...
dec_odd = dec_arr[1::2, :, :]   # Lines 1, 3, 5, ...

exp_even = exp_arr[::2, :, :]
exp_odd = exp_arr[1::2, :, :]

# Check correlation between decoded and expected for even vs odd lines
even_corr = np.corrcoef(dec_even.flatten(), exp_even.flatten())[0, 1]
odd_corr = np.corrcoef(dec_odd.flatten(), exp_odd.flatten())[0, 1]

print(f"Even lines correlation: {even_corr:.3f}")
print(f"Odd lines correlation: {odd_corr:.3f}")

if abs(even_corr - odd_corr) > 0.1:
    print("WARNING: Significant difference between even/odd line correlations!")
    print("This might indicate a Y0/Y1 assignment issue in frame decoding.")
else:
    print("Even and odd lines have similar correlation - frame structure looks correct")

# Check if there's a horizontal shift between even and odd lines
print("\n=== Checking for horizontal alignment between line pairs ===")
for shift in [-5, -3, -1, 0, 1, 3, 5]:
    if shift == 0:
        even_shifted = dec_even
        odd_compare = dec_odd
    elif shift > 0:
        even_shifted = dec_even[:, shift:, :]
        odd_compare = dec_odd[:, :-shift, :]
    else:
        even_shifted = dec_even[:, :shift, :]
        odd_compare = dec_odd[:, -shift:, :]
    
    corr = np.corrcoef(even_shifted.flatten(), odd_compare.flatten())[0, 1]
    if shift == 0:
        baseline_corr = corr
    print(f"Shift {shift:+d}: correlation = {corr:.3f}")
