# Halo pet keyframe atlases

The `cat`, `dog`, and `fox` folders share the same five atlas names and row
semantics. Every PNG uses 200 × 200 pixel cells and eight columns. Read row
metadata from `manifest.json`.

Animations originally designed for 12 or 16 frames contain eight generated key
poses. Halo should hold or interpolate those key poses to the `playbackFrames`
value. Mirrored and reversible states are marked in the manifest.
