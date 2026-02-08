#!/usr/bin/env python3
import os
import sys
from PIL import Image
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

# Check if there's a scaling/offset relationship
print("=== Linear relationship between decoded and expected ===")
for ch_name, ch in [('R', 0), ('G', 1), ('B', 2)]:
    d = dec_arr[:,:,ch].flatten()
    e = exp_arr[:,:,ch].flatten()
    
    # Fit linear: expected = a * decoded + b
    A = np.vstack([d, np.ones(len(d))]).T
    result = np.linalg.lstsq(A, e, rcond=None)
    a, b = result[0]
    
    print(f"{ch_name}: expected = {a:.3f} * decoded + {b:.1f}")

# Check histogram shapes
print("\n=== Histogram comparison ===")
for ch_name, ch in [('R', 0), ('G', 1), ('B', 2)]:
    d_min, d_max = dec_arr[:,:,ch].min(), dec_arr[:,:,ch].max()
    e_min, e_max = exp_arr[:,:,ch].min(), exp_arr[:,:,ch].max()
    print(f"{ch_name}: Decoded [{d_min:.0f}-{d_max:.0f}], Expected [{e_min:.0f}-{e_max:.0f}]")

# Check a horizontal line profile
print("\n=== Line 200 profile analysis ===")
y = 200
dec_line = dec_arr[y, :, :]
exp_line = exp_arr[y, :, :]

# Look for pattern differences - is there a consistent offset in specific regions?
print("\nLeft side (0-100):")
print(f"  Decoded mean: R={dec_line[:100, 0].mean():.1f}, G={dec_line[:100, 1].mean():.1f}, B={dec_line[:100, 2].mean():.1f}")
print(f"  Expected mean: R={exp_line[:100, 0].mean():.1f}, G={exp_line[:100, 1].mean():.1f}, B={exp_line[:100, 2].mean():.1f}")

print("\nMiddle (270-370):")
print(f"  Decoded mean: R={dec_line[270:370, 0].mean():.1f}, G={dec_line[270:370, 1].mean():.1f}, B={dec_line[270:370, 2].mean():.1f}")
print(f"  Expected mean: R={exp_line[270:370, 0].mean():.1f}, G={exp_line[270:370, 1].mean():.1f}, B={exp_line[270:370, 2].mean():.1f}")

print("\nRight side (540-640):")
print(f"  Decoded mean: R={dec_line[540:, 0].mean():.1f}, G={dec_line[540:, 1].mean():.1f}, B={dec_line[540:, 2].mean():.1f}")
print(f"  Expected mean: R={exp_line[540:, 0].mean():.1f}, G={exp_line[540:, 1].mean():.1f}, B={exp_line[540:, 2].mean():.1f}")

# Check if the image looks washed out / has compression issues
print("\n=== Checking for color desaturation ===")
# Convert to YCrCb space and compare
from PIL import ImageEnhance

# The issue might be that decoded colors are less saturated
dec_rgb = Image.fromarray(dec_arr.astype(np.uint8))
exp_rgb = Image.fromarray(exp_arr.astype(np.uint8))

# Try adjusting contrast
contrast_enhanced = ImageEnhance.Contrast(dec_rgb).enhance(1.3)
contrast_arr = np.array(contrast_enhanced).astype(float)
diff_after = np.abs(contrast_arr - exp_arr)
print(f"After 1.3x contrast enhancement, mean diff: {diff_after.mean():.1f}")

# Try adjusting saturation
saturation_enhanced = ImageEnhance.Color(dec_rgb).enhance(1.3)
saturation_arr = np.array(saturation_enhanced).astype(float)
diff_after = np.abs(saturation_arr - exp_arr)
print(f"After 1.3x saturation enhancement, mean diff: {diff_after.mean():.1f}")

# Try both
both_enhanced = ImageEnhance.Contrast(ImageEnhance.Color(dec_rgb).enhance(1.2)).enhance(1.1)
both_arr = np.array(both_enhanced).astype(float)
diff_after = np.abs(both_arr - exp_arr)
print(f"After 1.2x saturation + 1.1x contrast, mean diff: {diff_after.mean():.1f}")

# Save enhanced version
enhanced_path = os.path.join(PROJECT_ROOT, 'output_enhanced.png')
both_enhanced.save(enhanced_path)
print(f"\nSaved enhanced version to {enhanced_path}")

# Compare with different levels
print("\n=== Testing level adjustments ===")
for factor in [0.8, 0.9, 1.0, 1.1, 1.2]:
    adjusted = np.clip(dec_arr * factor, 0, 255)
    diff = np.abs(adjusted - exp_arr).mean()
    print(f"Scale factor {factor}: mean diff = {diff:.1f}")
