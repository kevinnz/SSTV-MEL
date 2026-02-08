# Sample SSTV Recordings

This directory contains SSTV (Slow-Scan Television) audio recordings used for testing and validating the decoder. Files are organised by SSTV mode.

## Sources and Licensing

### PD120 and PD180

Recordings from ARISS (Amateur Radio on the International Space Station) SSTV events, received and shared by amateur radio operators. These were publicly broadcast on 145.800 MHz as part of commemorative SSTV events organised by ARISS.

| File | Event | Date |
|------|-------|------|
| `PD120/...ARISS_20_Year_-_image_1.wav` | ARISS 20th Anniversary | 2017-07-23 |
| `PD120/...ARISS_20_Year_-_image_2.wav` | ARISS 20th Anniversary | 2017-07-23 |
| `PD180/...80th_Yuri_Gagarin_image_5.wav` | Yuri Gagarin 80th Birthday | 2015-04-12 |
| `PD180/...Apollo_Souz_American_and_USSR_flag.wav` | Apollo-Soyuz Commemoration | 2015-07-19 |
| `PD180/...ARISS_1st_QSO_-_Astros_-_and_Kids_image_9.wav` | ARISS 1st QSO Anniversary | 2016-04-12 |
| `PD180/...ARISS_1st_QSO_-_Cristoforetti_Garriot_image_4.wav` | ARISS 1st QSO Anniversary | 2016-04-13 |
| `PD180/...MAI-75_-_SuitSat_image_9.wav` | MAI-75 / SuitSat | 2016-04-15 |

ARISS SSTV transmissions are public broadcasts intended for reception by the amateur radio community worldwide. Recordings of these transmissions are freely shared among amateur radio operators and are commonly redistributed for educational and technical purposes.

### Robot36

Recordings of Robot36-mode SSTV transmissions from amateur radio operators. These include callsign identifications (PT7APM, HB100JAM, LX95), historical photographs, and QSL cards — all standard amateur radio SSTV activity.

Amateur radio SSTV transmissions are public broadcasts on allocated frequencies. Recordings are routinely shared within the amateur radio community for educational and technical use.

## Usage

These files serve as integration test inputs for the SSTV decoder. The corresponding expected output images are in the `expected/` directory at the project root.

```bash
# Decode a sample
swift run sstv samples/PD180/Space_Comms_-_2015-04-12_-_0428_UTC_-_80th_Yuri_Gagarin_image_5.wav

# Run automated tests against these samples
swift test
```

## File Format

All files are WAV format, mono, 16-bit PCM at either 44,100 Hz or 48,000 Hz sample rate. These files are tracked with [Git LFS](https://git-lfs.github.com/) — ensure you have Git LFS installed before cloning.
