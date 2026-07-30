# ClipboardX

Clipboard history for macOS — like Windows’ `Win+V`. Press `⇧⌘V` anywhere, pick
an earlier copy from a popup under your text cursor, and it pastes into the app
you were using.

ClipboardX remembers recent text, rich text, and images; lets you search, pin,
and delete items; and lives in the menu bar. Nothing leaves your Mac.

## Install

1. Download the latest **`.dmg`** from
   [Releases](https://github.com/ceyhununlu/clipboard-x/releases/latest).
2. Open it and drag **ClipboardX** into **Applications**.
3. Launch the app and grant **Accessibility** when macOS asks (needed for
   auto-paste and placing the popup at the caret).

Updates install automatically after that (or use **Check for Updates…** in the
menu bar). You do not need to download from GitHub again for new versions.

## How to use

| Shortcut | Action |
| --- | --- |
| `⇧⌘V` | Open clipboard history |
| `⌥⌘V` | Paste the latest item as plain text |
| `↑` / `↓` | Move through the list |
| `←` / `→` | Move the search caret |
| `Return` | Paste the selected item |
| `⌥Return` | Paste without formatting |
| `⌘1`–`⌘9` | Paste that row |
| `⌘P` | Pin / unpin |
| `⌘⌫` | Delete the selected item |
| Type to search | Filter the history |
| `Escape` | Clear search, then close |

Shortcuts and history size are configurable under **Settings…** in the menu bar
menu. Open at login is available there too.

## Where your data lives

```
~/Library/Application Support/ClipboardX/
  history.json    # previews, timestamps, pins
  blobs/          # payloads (content-addressed)
```

Preferences are in `UserDefaults` for `com.ceyhununlu.clipboardx`. History is
stored only on this Mac and is not encrypted (same idea as Windows clipboard
history). Delete an entry (`⌘⌫`) or clear history if you copy a password.

## License

[MIT](LICENSE)
