# ClipboardX

Clipboard history for macOS, in the spirit of Windows' `Win+V`. Press `⇧⌘V`
anywhere, a popup appears under your text cursor, you arrow to the item you want,
press Return, and it is pasted into whatever you were typing in.

**Open source. No App Store. No telemetry. Your clipboard never leaves your Mac.**

- Remembers the last 25 items (configurable, 5–200) — plain text, rich text, and
  **images**.
- Opens at the text caret of the focused app, so it behaves like part of the app
  you are already in.
- `↑`/`↓` to move, `Return` to paste, `⌥Return` to paste without formatting,
  `⌘1`–`⌘9` to grab a row directly, `Escape` to close.
- Type anything to search the history.
- Pin items (`⌘P`) so they are never evicted; delete one (`⌘⌫`) or clear the lot.
- Menu bar item with the eight most recent entries.
- Settings for history size, appearance (System / Light / Dark), shortcuts,
  image capture, and opening at login.
- No Dock icon, no third-party dependencies.

## Install without the App Store

You do **not** need an Apple Developer account or the App Store.

### Option A — download a release (easiest)

1. Open the repository’s [Releases](../../releases) page and download
   `ClipboardX-*-macos-universal.zip`.
2. Unzip it and drag `ClipboardX.app` into `/Applications`.
3. First launch: **right-click** the app → **Open** → confirm. macOS Gatekeeper
   blocks ad-hoc / unsigned downloads once; this is normal and does **not**
   mean the file is malware.
4. Grant **Accessibility** when prompted (needed for auto-paste and placing the
   popup at the caret).

Release builds are produced by GitHub Actions on every `v*` tag. They are
**ad-hoc signed only** — no Developer ID certificate is used, stored, or
exposed in CI.

If macOS still refuses to open the app: System Settings → Privacy & Security →
scroll to the blocked-app message → **Open Anyway**.

### Option B — build from source

```bash
git clone https://github.com/<you>/clipboard-x.git
cd clipboard-x
make verify     # tests + build/ClipboardX.app
make install    # copy to /Applications and launch
```

| Command | What it does |
| --- | --- |
| `make test` | Run the whole test suite |
| `make app` | Build `build/ClipboardX.app` (universal, **ad-hoc** signed) |
| `make dist` | Build + zip for distribution (`build/ClipboardX-*-macos-universal.zip`) |
| `make run` | Build and launch from `./build` |
| `make stop` | Quit a running instance |
| `make logs` | Stream the app's log output |
| `make reset-data` | Delete the stored history and preferences |
| `make reset-permissions` | Forget the Accessibility grant |
| `make clean` | Remove build products |

Requirements: macOS 15+, Xcode / Swift 6.2 toolchain.

#### Signing (local only)

```bash
# Default / CI / Releases — ad-hoc, no certificates involved
make app

# Local convenience — use your Apple Development identity so Accessibility
# grants survive rebuilds (identity stays in your keychain; never committed)
IDENTITY=auto make app
IDENTITY=auto make install
```

This project **never** commits certificates, private keys, provisioning
profiles, or `.env` files. CI forces `IDENTITY=-` and refuses to package a
non-ad-hoc signed app.

## Accessibility permission

macOS will not let one app type into another without permission. ClipboardX asks
for **Accessibility** on first launch and, if you decline, again from the menu
bar item or Settings → Permission.

It needs the permission for two things:

- pressing `⌘V` for you in the app you were typing in, and
- finding your text caret so the popup appears in the right place.

Everything else — recording your clipboard, searching it, copying an item — works
without it. With the permission missing, choosing an item still puts it on the
clipboard; you just press `⌘V` yourself, and the popup opens at the mouse
pointer instead of the caret.

macOS ties the grant to the app's **code signature**, not the name in the list.
Ad-hoc Release builds change signature on each update, so you may need to toggle
Accessibility off and on once after upgrading. Local builds with
`IDENTITY=auto` keep a stable grant across rebuilds.

## Appearance

ClipboardX follows **System** Light/Dark by default (menu bar, settings, and the
history popup all use system materials and semantic colors). Force Light or Dark
in **Settings → General → Appearance**.

## Shortcuts

Global (reconfigurable in Settings → Shortcuts):

| Shortcut | Action |
| --- | --- |
| `⇧⌘V` | Open the clipboard history |
| `⌥⌘V` | Paste the most recent item as plain text |

Inside the popup:

| Key | Action |
| --- | --- |
| `↑` `↓` | Move the selection |
| `Page Up` / `Page Down` / `Home` / `End` | Move faster |
| `Return` | Paste the selected item |
| `⌥Return` | Paste it without formatting |
| `⌘1`–`⌘9` | Paste that row directly |
| `⌘P` | Pin or unpin the selection |
| `⌘⌫` | Delete the selection |
| any character | Search |
| `Escape` | Clear the search, then close |

## Where your data lives

```
~/Library/Application Support/ClipboardX/
  history.json         # the index: previews, timestamps, pins
  blobs/               # the payloads, content-addressed
```

Preferences are in `UserDefaults` under `com.ceyhununlu.clipboardx`. Nothing
leaves your machine and there is no network code in the app.

Clipboard history is stored unencrypted, which is also true of Windows'
clipboard history. If you copy a password, delete that entry (`⌘⌫`) or clear
the history.

## Architecture

Three layers, so that everything except the AppKit shell is unit-testable:

```
ClipboardX          executable, three lines, boots the app
└── ClipboardUI     AppKit/SwiftUI shell: popup, menu bar, settings, composition root
    └── ClipboardPlatform  macOS integration: pasteboard, Carbon hotkeys, AX caret, ⌘V, login item
        └── ClipboardCore  model, storage, dedup, capping, settings, key codes — no UI
```

`ClipboardCore` puts every OS-owned collaborator behind a protocol
(`PasteboardSource`, `BlobStoring`, `HistoryIndexStoring`, `KeyValueStore`), so
the tests run against in-memory fakes with no clipboard, disk, or defaults
involved.

Behaviour worth knowing about:

- **Dedup** — copying something you already have moves that entry to the top
  instead of adding a duplicate. Rich text is fingerprinted on its plain text,
  so the same words copied from two apps count as one entry.
- **Capping** — when the history is full the oldest *unpinned* entry is dropped.
  Pinned entries are never evicted.
- **Storage** — payloads are content-addressed, so copying the same image twice
  stores one file, and files are deleted only when no entry references them.
- **Self-writes** — pasting from history does not re-record the item, so the
  order you see is the order you copied in.

## Continuous integration

Trunk-based: all work merges to `main`. GitHub Actions (`.github/workflows/ci.yml`):

1. **Test** — `swift test` on every push and pull request to `main`.
2. **Build** — universal `ClipboardX.app`, ad-hoc signed (`IDENTITY=-`), zipped
   as a workflow artifact.
3. **Release** — pushing a tag `v1.2.3` publishes that zip to GitHub Releases.

No signing secrets are configured. See [CONTRIBUTING.md](CONTRIBUTING.md) and
[SECURITY.md](SECURITY.md).

## Tests

```bash
swift test                              # everything
swift test --filter ClipboardCoreTests  # one target
```

The suite covers the store (dedup, capping, pin protection, garbage collection,
corrupt-index recovery), persistence round-trips, the pasteboard adapter for all
three content kinds, hotkey registration, popup geometry on multiple displays,
settings (including appearance), and the popup's keyboard navigation. It needs
no permissions, touches neither the real clipboard nor the real history file,
and runs headlessly.

## License

[MIT](LICENSE).
