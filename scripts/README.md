# Development and Analysis Scripts

This directory contains Python utility scripts used for development, debugging, and analysis of SSTV decoder output.

## Scripts

### Image Comparison Tools

- **`compare_images.py`** - General-purpose image comparison tool with command-line arguments. Compares decoded output against expected reference images, calculates statistics, and detects alignment issues.

- **`compare_aligned.py`** - Specialized comparison for pre-aligned images. Analyzes pixel-by-pixel differences and generates side-by-side comparison images.

- **`visual_comparison.py`** - Creates detailed visual comparisons with multiple panels showing decoded output, expected reference, and enhanced difference maps. Includes analysis of even/odd line pairs to detect frame structure issues.

### Analysis Tools

- **`analyze_color.py`** - Analyzes color relationships between decoded and expected images. Tests linear relationships, histogram distributions, and explores color correction approaches including contrast, saturation, and gamma adjustments.

- **`analyze_freq.py`** - Analyzes frequency mapping and color space transformations. Examines the relationship between SSTV frequency ranges (1500-2300 Hz) and pixel values, useful for debugging demodulation issues.

## Usage

All scripts accept optional command-line arguments for the decoded and expected image paths. If no arguments are provided, they fall back to project-relative defaults.

```bash
# Using defaults (relative to project root)
python3 scripts/compare_images.py

# Using custom paths
python3 scripts/compare_images.py path/to/decoded.png path/to/expected.jpg
```

These scripts are development and diagnostic utilities used during decoder development and testing.

## Requirements

- Python 3
- PIL/Pillow (`pip install Pillow`)
- NumPy (`pip install numpy`)
