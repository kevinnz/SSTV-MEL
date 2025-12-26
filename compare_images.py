#!/usr/bin/env python3
import sys
from PIL import Image
import numpy as np

# Load both images - accept command line args or use defaults
if len(sys.argv) >= 3:
    decoded_path = sys.argv[1]
    expected_path = sys.argv[2]
else:
    decoded_path = '/Users/kevin/Documents/GitHub/SSTV-MEL/output_synced.png'
    expected_path = '/Users/kevin/Documents/GitHub/SSTV-MEL/expected/PD180/Space_Comms_-_2015-04-12_-_0428_UTC_-_80th_Yuri_Gagarin_image_5.jpg'

decoded = Image.open(decoded_path)
expected = Image.open(expected_path)

print("=== Image Dimensions ===")
print(f"Decoded:  {decoded.size} ({decoded.mode})")
print(f"Expected: {expected.size} ({expected.mode})")

# Convert both to RGB numpy arrays
dec_arr = np.array(decoded.convert('RGB'))
exp_arr = np.array(expected.convert('RGB'))

# Resize expected to match decoded if needed
if dec_arr.shape != exp_arr.shape:
    expected_resized = expected.resize(decoded.size, Image.Resampling.LANCZOS)
    exp_arr = np.array(expected_resized.convert('RGB'))
    print(f"Resized expected to: {expected_resized.size}")

print("\n=== Pixel Statistics ===")
print(f"Decoded - R: mean={dec_arr[:,:,0].mean():.1f}, G: mean={dec_arr[:,:,1].mean():.1f}, B: mean={dec_arr[:,:,2].mean():.1f}")
print(f"Expected - R: mean={exp_arr[:,:,0].mean():.1f}, G: mean={exp_arr[:,:,1].mean():.1f}, B: mean={exp_arr[:,:,2].mean():.1f}")

# Calculate difference
diff = np.abs(dec_arr.astype(float) - exp_arr.astype(float))
print(f"\n=== Difference Analysis ===")
print(f"Mean absolute difference: {diff.mean():.1f}")
print(f"Max difference: {diff.max():.0f}")

# Check for horizontal shift by comparing rows
print("\n=== Checking for horizontal shift (row 100) ===")
row = 100
dec_row = dec_arr[row, :, :]
exp_row = exp_arr[row, :, :]

best_shift = 0
best_corr = -1
for shift in range(-100, 101):
    if shift >= 0:
        d = dec_row[shift:, :]
        e = exp_row[:len(d), :]
    else:
        e = exp_row[-shift:, :]
        d = dec_row[:len(e), :]
    
    if len(d) > 100:
        corr = np.corrcoef(d.flatten(), e.flatten())[0, 1]
        if corr > best_corr:
            best_corr = corr
            best_shift = shift

print(f"Best horizontal shift: {best_shift} pixels (correlation: {best_corr:.3f})")

# Check for vertical shift
print("\n=== Checking for vertical shift (col 320) ===")
col = 320
dec_col = dec_arr[:, col, :]
exp_col = exp_arr[:, col, :]

best_vshift = 0
best_vcorr = -1
for shift in range(-50, 51):
    if shift >= 0:
        d = dec_col[shift:, :]
        e = exp_col[:len(d), :]
    else:
        e = exp_col[-shift:, :]
        d = dec_col[:len(e), :]
    
    if len(d) > 50:
        corr = np.corrcoef(d.flatten(), e.flatten())[0, 1]
        if corr > best_vcorr:
            best_vcorr = corr
            best_vshift = shift

print(f"Best vertical shift: {best_vshift} pixels (correlation: {best_vcorr:.3f})")

# Save comparison images
print("\n=== Creating comparison images ===")
comparison = Image.new('RGB', (decoded.width * 2, decoded.height))
comparison.paste(decoded, (0, 0))
comparison.paste(expected.resize(decoded.size, Image.Resampling.LANCZOS), (decoded.width, 0))
comparison.save('/Users/kevin/Documents/GitHub/SSTV-MEL/comparison.png')
print("Saved side-by-side comparison to comparison.png")

diff_img = Image.fromarray(np.clip(diff * 2, 0, 255).astype(np.uint8))
diff_img.save('/Users/kevin/Documents/GitHub/SSTV-MEL/difference.png')
print("Saved difference map to difference.png")

# Check if colors are swapped
print("\n=== Checking color channel correlation ===")
for ch_name, ch in [('R', 0), ('G', 1), ('B', 2)]:
    for exp_ch_name, exp_ch in [('R', 0), ('G', 1), ('B', 2)]:
        corr = np.corrcoef(dec_arr[:,:,ch].flatten(), exp_arr[:,:,exp_ch].flatten())[0, 1]
        if corr > 0.3:
            print(f"Decoded {ch_name} vs Expected {exp_ch_name}: {corr:.3f}")

# Check specific regions - sample a few pixels
print("\n=== Sample pixel comparison ===")
for y, x in [(50, 50), (100, 320), (200, 200), (300, 400)]:
    print(f"({x},{y}): Decoded={dec_arr[y,x]} Expected={exp_arr[y,x]}")
