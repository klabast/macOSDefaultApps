# macOSDefaultApps

Set which app opens which file extension, UTI or URL scheme on macOS.

A modern successor to [RCDefaultApp](https://www.rubicode.com/Software/RCDefaultApp/), [SwiftDefaultApps](https://github.com/Lord-Kamina/SwiftDefaultApps) and [duti](https://github.com/moretension/duti).

Ships as a macOS app and a CLI (`mda`). Requires macOS 15+.

## App

![By type: families in the sidebar, handler dropdown per row](docs/screenshots/by-type.png)

- Browse types by family, or by app to see everything one app handles
- Change a handler from the dropdown in each row, or pick any app via "Other…"
- Filter across extensions, UTIs and app names (⌘F)
- Covers every type and URL scheme your installed apps declare
- English, Deutsch, Français, Español, Italiano, Português, Nederlands, Polski, 简体中文

## CLI

```sh
mda get md                          # default handler for .md
mda ls md                           # all candidates, default marked *
mda set com.sublimetext.4 md
mda set com.apple.Safari public.html
mda set com.apple.Mail mailto:
mda dump                            # curated types with handlers (or --json)
mda dump --all                      # every type your installed apps declare
mda save                            # snapshot handlers to ~/.mda/default
mda apply                           # restore the default preset
mda apply work                      # a named preset (~/.mda/work)
mda apply settings.duti             # any duti settings file
mda apply initial                   # undo: the state before mda touched this mac
mda --version
```

`md` and `.md` are extensions, `public.html` is a UTI, `mailto:` is a URL scheme. mda classifies the target itself.

## Presets

`mda save` writes the current associations to `~/.mda/`, one plain-text file per preset, duti syntax. Put the folder in your dotfiles. It warns when the folder isn't under git.

`mda apply` restores a preset. Apps that aren't installed are skipped and listed, and the exit code is non-zero so a bootstrap script can react. Re-run it after installing them.

The app has the same thing under **Presets**, with a preview before anything is written.

## The restore point

Before mda changes anything for the first time, it records how the machine already looked. Written once, never rewritten.

```sh
mda apply initial                   # put it all back
```

It isn't a preset and isn't in `~/.mda` — it lives in `~/Library/Application Support/mda`, because it describes one machine and would be wrong on any other. Keep `~/.mda` in your dotfiles; this stays behind. [ADR 0002](docs/adr/0002-restore-point-is-machine-state-not-a-preset.md).

## duti settings files

`mda apply` reads them as-is. Three-field lines (`bundle-id  uti  role`) work unchanged; the role column is ignored. Two fields mean a URL scheme, like `duti -s`.

## Install

```sh
brew tap klabast/tap
brew trust klabast/tap                  # required for third-party taps
brew install --cask macosdefaultapps    # app, with mda bundled in
brew install mda                        # cli on its own
```

Neither needs Xcode. The app is also on the [latest release](https://github.com/klabast/macOSDefaultApps/releases/latest) page.

Build from source:

```sh
swift build -c release            # cli: .build/release/mda
scripts/package-app.sh            # app: build/macOSDefaultApps.app
```

## Notes

- Changing the default browser triggers a macOS consent dialog. It can't be silenced.
- There is no API to remove an association, only to point it somewhere else. LaunchServices clears out stale ones.
- The extension `ts` is MPEG-2 Transport Stream system-wide, not TypeScript.

## License

MIT
