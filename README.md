# Stenographer

Dictation for the macOS menu bar. Hold the **right Option** key, speak, and release. The text is
pasted into the app you are using.

- Speech recognition runs on your Mac with Parakeet TDT 0.6B v3 (25 European languages, found
  automatically). The app downloads the model (about 480 MB) the first time it starts.
- A short tap of right Option does nothing. If you press another key while you hold right Option
  (for example ⌥3 for #), the recording stops and nothing is pasted.
- Your clipboard is put back after the paste.

Needs macOS 26 and two permissions, which the menu asks for: Microphone and Accessibility.

## Build

```sh
brew install xcodegen
xcodegen generate
open Stenographer.xcodeproj
```

Put your team in `Local.xcconfig` (not committed): `DEVELOPMENT_TEAM = XXXXXXXXXX`.

## License

MIT. See `LICENSE`. Code adapted from OpenSuperWhisper is listed in `THIRD_PARTY_NOTICES.md`.
