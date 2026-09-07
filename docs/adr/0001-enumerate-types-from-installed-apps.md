# 0001 — enumerate types from installed apps, not from launchservices

## context

the app and cli both need a list of "types you can set a default for". there is no
public api to enumerate the launchservices database, so from the start this was
treated as a hard problem with three bad options, recorded in
`docs/plans/0001-rebuild.md`:

- a curated list shipped as data (what we did — `Resources/catalog.json`)
- parsing `lsregister -dump`
- the private `LSCopySchemesAndHandlerURLs`, as SwiftDefaultApps used

the curated catalog covers 63 extensions and 7 schemes. it covers the mainstream
formats well, but it is a hard ceiling: anything not in the file does not exist as
far as the ui is concerned, and the `by app` view is built from the handlers of
those 70 targets, so it inherits the same ceiling.

## decision

enumerate **installed applications** and read what each one declares in its own
`Info.plist`:

- `CFBundleDocumentTypes` → `CFBundleTypeExtensions`
- `UTExportedTypeDeclarations` / `UTImportedTypeDeclarations` →
  `UTTypeTagSpecification["public.filename-extension"]`
- `CFBundleURLTypes` → `CFBundleURLSchemes`

the union is the set of things that can actually be reassigned on this machine. all
public api, no private calls, nothing that rots across macos releases.

apps are found by walking `/Applications`, `~/Applications`, `/System/Applications`
and `/System/Library/CoreServices`. spotlight (`kMDItemContentType ==
'com.apple.application-bundle'`) was measured as an alternative and rejected: it
finds 370 bundles against the directory walk's 245, but the extra 125 are nested
system helpers that add 12 extensions and one scheme
(`x-apple.voiceover.training`). not worth an index dependency that silently returns
nothing when spotlight is disabled.

the catalog is kept. it is no longer the ceiling — it is the curated front page,
and `Catalog.extended(with:)` appends what the scan found that the families do not
already cover.

## consequences

measured on a normal machine, 245 app bundles:

| | curated | discovered |
|---|---|---|
| extensions | 63 | 1295 |
| url schemes | 7 | 185 |
| scan cost | — | 55 ms |

of the discovered extensions, ~1170 resolve to a type with at least one handler,
and 183 of 185 schemes already have a default set.

- **the "no public api for url schemes" problem is closed.** it was the wrong
  question: we never needed the launchservices database, only the union of what
  installed apps claim.
- **~700 extensions resolve to dynamic (`dyn.`) utis** rather than declared ones —
  no app formally declares a uti, so macos synthesises one from the extension.
  associations keyed on those are the shakier path; set by extension there.
  `LaunchServicesRegistry.typeIdentifier(forExtension:)` already documents this.
- **the long tail is long**: 755 extensions are declared by exactly one app. a flat
  list of 1295 would be worse ux than the curated 63, so discovery belongs behind
  search and an "other" grouping, never as the default view.
- the scan reflects installed apps, so it changes when apps are installed or
  removed. it is cheap enough (55 ms) to redo on demand rather than cache.
- `TypeDiscovery` is a port like `HandlerRegistry`, so the ui and cli can be tested
  against a fake without touching the real filesystem.
