# ROBOT36 SSTV Mode Specification (Implementation Notes)

## Overview

ROBOT36 transmits a 320x240 image in ~36 seconds.
It uses YCbCr 4:2:0 color encoding:
- Luminance (Y) is sent for every line
- Chrominance (R-Y, B-Y) is shared across pairs of lines

Two transmitted lines form one logical decode frame.

## VIS Code
- Decimal: 8
- Hex: 0x08

## Frequencies

- Sync: 1200 Hz
- Black: 1500 Hz
- White: 2300 Hz
- Chroma zero reference: 1900 Hz

## Timing per line (milliseconds)

### Even line
| Segment            | Duration |
|--------------------|----------|
| Sync pulse         | 9.0 ms   |
| Sync porch         | 3.0 ms   |
| Y scan             | 88.0 ms  |
| Separator (R-Y)    | 4.5 ms   |
| Chroma porch       | 1.5 ms   |
| R-Y scan           | 44.0 ms  |

### Odd line
| Segment            | Duration |
|--------------------|----------|
| Sync pulse         | 9.0 ms   |
| Sync porch         | 3.0 ms   |
| Y scan             | 88.0 ms  |
| Separator (B-Y)    | 4.5 ms   |
| Chroma porch       | 1.5 ms   |
| B-Y scan           | 44.0 ms  |

## Frame structure

One frame consists of:
- Even line Y + R-Y
- Odd line Y + B-Y

Total frame duration ≈ 300 ms

## Decoding rules

- Decode two lines per frame
- Chroma applies to both lines
- Convert Y, R-Y, B-Y to RGB using standard YCbCr conversion
- Clamp RGB output to 0.0 ... 1.0
