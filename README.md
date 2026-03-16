# wake-up-neo

A Matrix-inspired screen saver for macOS. Falling green half-width katakana and digits with bright leading heads and fading trails.

## Install

1. Download the latest `wake-up-neo.saver` from [Releases](https://github.com/candlemak3r/wake-up-neo/releases)
2. Double-click to install
3. Go to **System Settings > Screen Saver > Screen Saver... > Custom** and select **wake-up-neo**

## Build from source

```bash
git clone https://github.com/candlemak3r/wake-up-neo.git
cd wake-up-neo
xcodebuild -scheme wake-up-neo -configuration Release build
```

The `.saver` bundle will be in `DerivedData/wake-up-neo-*/Build/Products/Release/`.

## Tweaking

Edit the constants at the top of `wake-up-neo/wake_up_neoView.m`:

| Constant | Default | Effect |
|---|---|---|
| `kFontSize` | 16.0 | Character size |
| `kBrightnessDecay` | 0.045 | Trail fade speed (lower = longer trails) |
| `kSpawnChance` | 0.015 | Stream density (higher = more streams) |
| `kMutateChance` | 0.004 | Character flicker rate |

## Requirements

- macOS 13+
- Xcode 15+ (to build from source)

## License

MIT
