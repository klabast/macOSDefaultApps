# 0002 — the restore point is machine state, not a preset

## context

`mda` needs a first-run restore point: the associations as they were before mda
ever changed anything, so "i fucked up my defaults" has an answer. the obvious
shape is a preset named `initial` in `~/.mda`, captured on the first mutating
command and never rewritten. restoring is then `mda apply initial` and costs no
new code.

it is also wrong. `~/.mda` is documented as a dotfiles directory — the whole
point of presets is that they are shareable, versioned and carried between
machines. a restore point is the exact opposite: it describes the state of one
mac at one moment. committing `~/.mda` would carry `initial` to a second
machine, where its mere presence suppresses capture (the file exists, so the
first run there records nothing) and `mda apply initial` "restores" that machine
to associations it never had.

both properties are load-bearing and they contradict each other in one directory.

## decision

split the two by location.

| | path | shared? |
|---|---|---|
| presets | `~/.mda` | yes — dotfiles, git, one file per preset |
| restore point | `~/Library/Application Support/mda/initial` | no — one mac, never travels |

`Locations` owns both paths. the restore point is not a preset: it never appears
in `PresetStore.list()`, cannot be created or overwritten through `mda save`, and
`initial` is reserved as a preset name so nothing can shadow it.

`mda apply initial` still works — `Apply` resolves that one name against the
restore point before it looks at presets or paths. `mda apply ./initial` still
reads a file, since the path cases are unchanged.

capture is lazy: the catalog closure is only evaluated on the run that actually
writes, so the ~1500-target walk is paid once and never again.

## consequences

- **the hazard is closed structurally**, not by convention. there is no way to
  commit the restore point to a dotfiles repo, because it is not in one.
- **application support is the right home on macos** and the app is not
  sandboxed, so the cli and the app resolve to the same path. a sandboxed build
  would land in a container and see a different restore point — if the app is
  ever sandboxed, that has to be revisited.
- **two env overrides** (`MDA_PRESETS_DIR`, `MDA_STATE_DIR`) exist so the cli can
  be run end to end against throwaway directories. `Tests/MDATests` uses them to
  drive the real binary; without them the only way to test the wiring was to
  aim it at the developer's own `~/.mda`, which is how this feature's first
  version overwrote one.
- **existing users get a restore point that is not pristine.** anyone who has run
  mda before gets a snapshot of today, not of before-mda. nothing can recover the
  earlier state, so the file is honest about what it is rather than pretending.
- one more directory to explain in the readme, against one class of silent
  cross-machine corruption. worth it.
