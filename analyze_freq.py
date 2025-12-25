#!/usr/bin/env python3
"""Analyze the actual frequency values detected from the SSTV signal."""
from PIL import Image
import numpy as np

# The decoded image uses normalized values (0-255) which came from frequency mapping
# frequency_normalized = (freq - 1500) / 800 => pixel = normalized * 255
# So pixel_value = ((freq - 1500) / 800) * 255

# From our analysis: expected ≈ 0.74 * decoded + 28
# Let's work backwards to understand what this means

# If decoded uses standard mapping and expected is from "correct" decoder:
# Let decoded = ((freq - 1500) / 800) * 255
# Then expected = 0.74 * decoded + 28
#              = 0.74 * ((freq - 1500) / 800) * 255 + 28
#              = 0.74 * ((freq - 1500) / 800) * 255 + 28

# For black (freq = 1500): decoded = 0, expected = 28
# For white (freq = 2300): decoded = 255, expected = 0.74 * 255 + 28 = 216.7

print("=== Frequency mapping analysis ===")
print()

# Observed relationship from linear regression
a = 0.74  # scale
b = 28    # offset

print("If decoded image uses 1500-2300 Hz mapping:")
print(f"  Black (1500 Hz) -> decoded=0, expected should be ~{a * 0 + b:.0f}")
print(f"  White (2300 Hz) -> decoded=255, expected should be ~{a * 255 + b:.0f}")
print()

# Load both images and check the darkest and brightest pixels
decoded = Image.open('/Users/kevin/Documents/GitHub/SSTV-MEL/output_synced.png')
expected = Image.open('/Users/kevin/Documents/GitHub/SSTV-MEL/expected/Space_Comms_-_2015-04-12_-_0428_UTC_-_80th_Yuri_Gagarin_image_5.jpg')

dec_arr = np.array(decoded.convert('RGB'))
exp_arr = np.array(expected.convert('RGB'))

print("=== Actual extremes in images ===")
print(f"Decoded: min={dec_arr.min()}, max={dec_arr.max()}")
print(f"Expected: min={exp_arr.min()}, max={exp_arr.max()}")

# The expected image probably has JPEG compression which affects values
# Let's look at specific regions

# Find a region that should be very dark (background)
print("\n=== Dark region analysis (top-left corner, presumably background) ===")
dark_dec = dec_arr[10:30, 10:30, :]
dark_exp = exp_arr[10:30, 10:30, :]
print(f"Decoded dark region: mean={dark_dec.mean():.1f}, std={dark_dec.std():.1f}")
print(f"Expected dark region: mean={dark_exp.mean():.1f}, std={dark_exp.std():.1f}")

# Find a bright region (if there's text or white area)
print("\n=== Finding bright regions ===")
gray_dec = np.mean(dec_arr, axis=2)
gray_exp = np.mean(exp_arr, axis=2)

bright_mask_dec = gray_dec > 200
bright_mask_exp = gray_exp > 200

if bright_mask_dec.sum() > 0:
    print(f"Decoded: {bright_mask_dec.sum()} bright pixels, mean={gray_dec[bright_mask_dec].mean():.1f}")
else:
    print("Decoded: no pixels > 200")

if bright_mask_exp.sum() > 0:
    print(f"Expected: {bright_mask_exp.sum()} bright pixels, mean={gray_exp[bright_mask_exp].mean():.1f}")
else:
    print("Expected: no pixels > 200")

# The issue might be that the expected image is from a different source
# (possibly an SDR decoder or a different implementation)
# Let's see if adjusting our output makes it match better

print("\n=== Testing correction formulas ===")

# Try applying the inverse of our measured relationship
# If expected = 0.74 * decoded + 28
# Then corrected = (decoded - 28) / 0.74 wouldn't work (values would go negative)
# The relationship suggests our decoded values need to be rescaled

# Actually, re-reading: expected = 0.74 * decoded + 28
# This means decoded has MORE range than expected (darker darks, brighter brights)
# Our decoded image appears to have MORE contrast than expected

# Let's try rescaling decoded to match expected's range
dec_min = dec_arr.min()
dec_max = dec_arr.max()
exp_min = exp_arr.min()
exp_max = exp_arr.max()

# Linear rescale: new = (old - old_min) * (new_max - new_min) / (old_max - old_min) + new_min
corrected = (dec_arr.astype(float) - dec_min) * (exp_max - exp_min) / (dec_max - dec_min) + exp_min
corrected = np.clip(corrected, 0, 255).astype(np.uint8)

diff_original = np.abs(dec_arr.astype(float) - exp_arr.astype(float)).mean()
diff_corrected = np.abs(corrected.astype(float) - exp_arr.astype(float)).mean()

print(f"Original mean diff: {diff_original:.1f}")
print(f"After linear rescale: {diff_corrected:.1f}")

# Save corrected version
Image.fromarray(corrected).save('/Users/kevin/Documents/GitHub/SSTV-MEL/output_rescaled.png')
print("Saved rescaled version to output_rescaled.png")

# Try gamma correction
print("\n=== Testing gamma correction ===")
for gamma in [0.8, 0.9, 1.0, 1.1, 1.2]:
    gamma_corrected = np.power(dec_arr / 255.0, gamma) * 255
    gamma_corrected = np.clip(gamma_corrected, 0, 255).astype(np.uint8)
    diff = np.abs(gamma_corrected.astype(float) - exp_arr.astype(float)).mean()
    print(f"Gamma {gamma}: mean diff = {diff:.1f}")

# The most likely issue: the expected image went through different processing
# (JPEG compression, different decoder, etc.)
print("\n=== Checking if expected might have been through JPEG compression ===")
# JPEG tends to make midtones more uniform
mid_mask = (gray_exp > 100) & (gray_exp < 150)
if mid_mask.sum() > 0:
    dec_mid_std = gray_dec[mid_mask].std()
    exp_mid_std = gray_exp[mid_mask].std()
    print(f"Midtone std - Decoded: {dec_mid_std:.1f}, Expected: {exp_mid_std:.1f}")
    if exp_mid_std < dec_mid_std:
        print("Expected has lower variance in midtones - consistent with JPEG compression")
