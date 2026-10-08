# FlashCull

Apple Silicon command-line photo culling engine. It analyzes bounded batches concurrently, scores technical quality, detects closed eyes, groups perceptual duplicates, and writes non-destructive Adobe/Capture One XMP ratings.

## Build

```sh
swift build -c release
```

## Establish a baseline

Use a representative local folder containing the camera formats and shooting conditions you actually deliver. Run every competing tool against the same folder on the same machine, with previews and caches cleared.

```sh
.build/release/flashcull benchmark /Volumes/Photos/Benchmark --workers 8 --json /tmp/flashcull.json
```

Face landmarks are the most expensive stage. Measure both the complete contract and preview-only technical throughput:

```sh
.build/release/flashcull benchmark /Volumes/Photos/Benchmark --workers 8 --no-faces
```

The command reports analyzed photos per second. Record total input bytes separately to calculate TB/hour; do not extrapolate from synthetic JPEGs to RAW archives.

## Cull and export metadata

First create a report without touching the photo directory:

```sh
.build/release/flashcull cull /Volumes/Photos/Shoot --json /tmp/shoot-cull.json
```

Then write ratings and labels:

```sh
.build/release/flashcull cull /Volumes/Photos/Shoot --write-xmp
```

Rejected files receive rating `-1` and label `Red`. Keepers receive 3–5 stars and label `Green`. Existing XMP sidecars are protected by default. `--overwrite-existing-xmp` replaces them and therefore must only be used after backup or on a fresh import.

In Lightroom Classic, enable **Automatically write changes into XMP**, then read metadata from files. In Capture One, enable metadata synchronization and load ratings/color tags from sidecars. Import behavior varies by catalog settings, so validate on a copied shoot first.

## Performance model

The engine uses ImageIO thumbnails rather than full-resolution pixel buffers and keeps only `workerCount` decodes in flight. The current duplicate index and final report are held in memory; this is suitable for benchmarking and individual shoots, not yet a claim of unlimited archive scale. Multi-terabyte production use requires a persistent index and checkpointed directory scanner after baseline measurements establish the actual bottleneck.

## Supported inputs

Common JPEG, HEIF, PNG, TIFF and camera RAW extensions are discovered. Actual RAW decoding depends on the macOS ImageIO camera support installed on the machine.
