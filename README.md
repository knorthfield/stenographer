<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Stenographer icon">
</p>

# Stenographer

Dictation for the macOS menu bar. Hold the **right Option** key, speak, and release. The text is
pasted into the app you are using.

- Speech recognition runs on your Mac with Parakeet TDT 0.6B v3 (25 European languages, see
  below). The app downloads the model (about 480 MB) the first time it starts.
- A short tap of right Option does nothing. If you press another key while you hold right Option
  (for example ⌥3 for #), the recording stops and nothing is pasted.
- Your clipboard is put back after the paste.

## Languages

Stenographer finds the language by itself. You do not choose it. It supports these 25 languages:

Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek,
Hungarian, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Russian, Slovak,
Slovenian, Spanish, Swedish and Ukrainian.

This is the list of the speech model,
[Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3).

## Install

Needs macOS 26 or later.

With [Homebrew](https://brew.sh):

```sh
brew install --cask knorthfield/tap/stenographer
```

Or download `Stenographer.zip` from the
[latest release](https://github.com/knorthfield/stenographer/releases/latest), unzip it, and move
`Stenographer.app` to Applications.

Then:

1. Open Stenographer. A waveform icon shows in the menu bar, and a window opens.
2. In the window, click **Allow…** for the microphone and for Accessibility, and turn Stenographer
   on in System Settings. The window closes when both are on. The menu has the same buttons.
3. Wait until the menu says **Hold right ⌥ to dictate**. The first time, the model must download.
   The window shows the progress.
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
