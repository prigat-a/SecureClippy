# Secure Clipboard

A small, lightweight clipboard history app for Apple Silicon Macs. History is locked behind Touch ID and is only ever kept encrypted in memory.

> [!WARNING]
> **Disclaimer: I'm a vibecoder, not a security expert.** This app was built with the help of AI tools and has not been professionally audited. It is provided as-is, without any warranty (see [LICENSE](LICENSE)). **If you use it, you do so at your own risk and are responsible for any consequences**, including for any sensitive data you copy while it's running.

## ⬇️ Download

**[Download the latest version for Mac](https://github.com/prigat-a/SecureClippy/releases/latest/download/SecureClipboard.zip)** (Apple Silicon, macOS 12+). The [landing page](https://prigat-a.github.io/SecureClippy/) has install steps.

Every change to the app on `main` is built and published automatically as a new [release](https://github.com/prigat-a/SecureClippy/releases), so that link always gets the newest build.

## 🙏 Help wanted

A clipboard manager sees everything you copy, so it should be checked by more eyes than mine. If you know Swift, macOS or security, I'd really appreciate your help:

- **Review the code**, especially the encryption in [ClipboardManager.swift](SecureClipboard/ClipboardManager.swift) and the unlock flow in [AuthenticationManager.swift](SecureClipboard/AuthenticationManager.swift)
- **Test it** on your Mac and macOS version, and with your password manager
- **Report problems** by [opening an issue](../../issues). Please report security issues privately via [GitHub security advisories](../../security/advisories/new) rather than in a public issue
- **Send fixes** as pull requests

Any feedback, big or small, is welcome. Thank you!

## Features

- Press **⌘⇧V** in any app to open a popup of your history and paste from it
- Clipboard history (text) with copy, delete and clear-all
- Unlock with Touch ID, or the account password if Touch ID isn't available
- Every entry encrypted with AES-256-GCM; text is decrypted only to show or copy it
- Skips items that password managers mark as concealed or transient
- Locks itself when the screen locks or the Mac sleeps
- Entries expire after 24 hours; history is capped at 200 items
- Native arm64 build, ~300 KB binary, ~0% CPU when idle

## Requirements

- Apple Silicon Mac (arm64)
- macOS 12.0 or later
- Xcode or the Xcode Command Line Tools (Swift 5.9+)

## Building and running

```bash
swift build -c release --arch arm64
```

```bash
.build/arm64-apple-macosx/release/SecureClipboard
```

For development, `swift run` builds and launches the debug build.

To package it as a double-clickable `Secure Clipboard.app` in this folder:

```bash
./build-app.sh
```

## Quick paste (⌘⇧V)

Press ⌘⇧V anywhere. A popup opens next to the mouse pointer (unlock with Touch ID if it's locked).

- **↑ / ↓** to pick an entry, **↩** or a click to paste it
- **1–9** to paste one of the first nine entries straight away
- **esc** or clicking elsewhere closes it

Pasting into the other app requires **Accessibility** permission. macOS asks for it the first time. Turn on Secure Clipboard in System Settings → Privacy & Security → Accessibility. Until then, picking an entry just copies it, and you press ⌘V yourself.

Because `build-app.sh` signs ad-hoc, macOS treats every rebuild as a new app. After rebuilding, remove the old Accessibility entry and turn the new one on.

The app keeps running after you close its window so ⌘⇧V keeps working. Quit it with ⌘Q.

## How it works

- The pasteboard's `changeCount` is checked every 0.5 s. Contents are only read when it changes, and the timer has tolerance so macOS can batch its wakeups.
- Each new text entry is sealed with AES-GCM using a random 256-bit key created at launch and held only in memory. Only the ciphertext and a SHA-256 digest (used to skip duplicates) are kept.
- Nothing is written to disk. Quitting the app throws away the key and the whole history.
- Copying continues to be recorded while the app is locked (that's the point of a clipboard manager), but entries can't be viewed until you unlock.
- Failed-attempt limits and lockout are handled by macOS's LocalAuthentication.

## Limitations

- The key lives in the same process as the ciphertext, so encryption protects against casual memory inspection and crash dumps, not against an attacker who can read the app's memory while it runs.
- Decrypted text shown in the UI is a normal Swift `String` and can't be reliably wiped from memory.
- Text only; images and files aren't recorded.

## License

MIT License
