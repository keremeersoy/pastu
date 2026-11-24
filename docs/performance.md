# Performance

Pastu's goal is to feel instant: press the shortcut and the panel is there. This page says how that is measured, so
anyone can repeat it, and what the numbers were on one machine. Numbers depend on the hardware; compare runs on the
same Mac, not across Macs.

## Opening the panel

`PanelOpenBenchmark` calls the panel controller's `show()` (the work on the main thread before the panel can draw: the
model reset, building the SwiftUI view, the first layout) 25 times for a history of a given size and prints the first
run, the median and the 95th percentile. It is off by default because it takes about a minute:

```bash
PASTU_BENCH=1 swift test --filter PanelOpenBenchmark
```

Read the `BENCH` lines. Screenshots in the test history are noisy 2880×1800 PNGs, about the size of a retina
screenshot. Their thumbnails are decoded in the background after the panel is up, so they do not appear in the open
time; that is the point of decoding them off the main thread.

What it does not measure: the time the window server and the display need after `show()` returns, and the delay of the
global shortcut itself. Those are small and not in Pastu's hands.

### Results

Measured on a MacBook (Mac16,12, Apple M4, 24 GB), macOS 27.2.1, debug build, on 2026-11-24:

| History | First open | Median | 95th percentile |
|---|---|---|---|
| empty | 61 ms | 31 ms | 43 ms |
| 5,000 text clips | 30 ms | 38 ms | 43 ms |
| 500 text clips + 20 screenshots | 66 ms | 40 ms | 47 ms |
| 60 screenshots | 35 ms | 41 ms | 46 ms |

Searching 5,000 text clips (six different queries, including a miss) takes about 1 ms each.

The open time does not grow with the history: the list loads a page of 100 clips and more as you scroll. A debug build
is slower than the release build that people use, so these are upper bounds.

## Memory

```bash
./scripts/measure-memory.sh            # any running Pastu
./scripts/measure-memory.sh path/to/Pastu.app
```

It prints the resident set size and the physical footprint of the process. Let Pastu sit for a minute with the panel
closed before reading it. The script reads only numbers about the process, never its contents.

### Results

A Pastu that had been running for more than a day on a real history, after reading the text in the old pictures
(see below) and after the panel had been opened many times, on the same Mac:

| | |
|---|---|
| Physical footprint, idle | 104 MB |
| Physical footprint, peak since launch | 163 MB |
| Resident set size | 162 MB |

That is more than a menu bar utility should need. Most of it is small heap allocations (67 MB) rather than pictures
(Image IO and IOSurface together are about 15 MB). Reading the text in pictures loads Apple's recognition models, and the
peak is likely from that catch-up pass; whether the models stay resident afterwards has not been verified. This is the
next thing to look at if idle memory matters: measure a fresh launch with "Find text in pictures" switched off, then on.

## Picture thumbnails

A retina-size screenshot took about 15 ms to turn into a list thumbnail on the main thread (20 screenshots: 315 ms).
Thumbnails are now made off the main thread; rows show a placeholder until theirs is ready.
