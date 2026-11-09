<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Stenographer icon">
</p>

# Stenographer

Dictation for the macOS menu bar. Hold the **right Option** key, speak, and release. The text is
pasted into the app you are using.

- Speech recognition runs on your Mac with Parakeet TDT 0.6B v3 (25 European languages, found
  automatically). The app downloads the model (about 480 MB) the first time it starts.
- A short tap of right Option does nothing. If you press another key while you hold right Option
  (for example ⌥3 for #), the recording stops and nothing is pasted.
- Your clipboard is put back after the paste.

## Install

Needs macOS 26 or later.

> The first release is not out yet ([#1](https://github.com/knorthfield/stenographer/issues/1)).
> Until then, build from source (below).

With [Homebrew](https://brew.sh):

```sh
brew install --cask knorthfield/tap/stenographer
```

Or download `Stenographer.zip` from the
[latest release](https://github.com/knorthfield/stenographer/releases/latest), unzip it, and move
`Stenographer.app` to Applications.

Then:

1. Open Stenographer. A waveform icon shows in the menu bar.
2. From that menu, click **Allow Microphone…** and **Allow Accessibility…**, and turn Stenographer
   on in System Settings.
3. Wait until the menu says **Hold right ⌥ to dictate**. The first time, the model must download.
4. Click in a text field, hold right Option, speak, and release.

Stenographer opens at login. You can turn this off in its menu.

## Build

```sh
brew install xcodegen
xcodegen generate
open Stenographer.xcodeproj
```

Put your team in `Local.xcconfig` (not committed): `DEVELOPMENT_TEAM = XXXXXXXXXX`.

## License

MIT. See `LICENSE`. Code adapted from OpenSuperWhisper is listed in `THIRD_PARTY_NOTICES.md`.
