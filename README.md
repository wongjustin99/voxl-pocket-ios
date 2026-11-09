# voxl-pocket-ios

A native iPhone and iPad client for [voxl](https://github.com/tembo/voxl), the low-latency remote
desktop server.

## Features

- H.264 video decoded in hardware (AVSampleBufferDisplayLayer), one layer per stripe
- Trackpad and touch input, pinch to zoom, two-finger scroll
- Hardware keyboards and mice, plus the soft keyboard with a key bar for Esc, Tab,
  sticky Shift/Cmd/Ctrl/Opt, ⌘Space, ⌘Tab and arrows
- Keeps the host at its own resolution by default; can resize it to fit the iPad
  (Large, Medium, More space) when the server runs with `--enable-resize`
- Switch between the host's displays
- Clipboard both ways, text and images
- Split View, Slide Over and any orientation

## Use

Tap **+** and enter the server's address, for example `wss://my-mac.example.com:6901/ws`,
and its password. The password is stored in the iOS Keychain.

### Cloudflare Tunnel with Access (GitHub login)

Point the tunnel's public hostname at the Voxl server's local HTTP port, and add that
hostname to Voxl's `--allowed-hosts`. Keep your existing Cloudflare Access policy.

1. Add `wss://desktop.example.com/ws` as a host. Its password is the **Voxl password**,
   not your GitHub password.
2. Tap the saved host. A Cloudflare Access login redirect automatically opens sign-in.
   You can also swipe left, tap **Access**, then **Sign In** to log in manually.
3. Complete Cloudflare's GitHub login in the in-app browser. The browser closes and
   the native desktop connects once the application cookies are available.

Access cookies are saved in the Keychain, scoped to that exact hostname and port.
The optional `CF_Binding` cookie is included too. The login browser uses temporary
storage, separate from Safari, so you may need to enter your GitHub credentials again.
Only HTTPS login pages are allowed; no Voxl password is sent to the login browser.
If a passkey or external-app login cannot complete inside the browser, use GitHub's
password and verification-code options instead.

When Access expires or rejects a connection, tap the desktop's sign-in message to
log in again. A 403 does not erase the saved Voxl password. To stop using Access for a
host, swipe left, tap **Access**, then **Turn Off in App**; this does not change the
server's Cloudflare policy. Deleting a host removes its saved password and Access cookies.

The real GitHub/Access flow must be tested against your protected hostname; local
unit tests do not validate your Access policy or identity-provider configuration.

## Privacy

Voxl Pocket collects no data and has no analytics, ads or accounts. The servers you add
are stored on your device, and their passwords in the iOS Keychain. The app talks only to
the servers you add: it sends your input, and your clipboard when it changes, and receives
the screen and the server's clipboard. When you enable Cloudflare Access, the sign-in
browser also contacts Cloudflare and your chosen identity provider (such as GitHub).
The app saves the application's Access cookies in the Keychain, not your GitHub password.
Nothing is sent to the app's developer.

## Build

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen
open VoxlPocket.xcodeproj
```

This fork uses `com.wongjustin99.VoxlPocket` and leaves `DEVELOPMENT_TEAM` empty.
To try it on an iPhone or iPad, open the generated project, select your Apple development team
under **Signing & Capabilities**, select your connected device, and run. Change the bundle
identifier if your team cannot register this one. Set the team in `project.yml` if you
want it retained when regenerating the project.

Run the cookie-scoping and handshake-error tests with `swift test`.
The Xcode scheme also includes a live integration test against `voxl.mailwong.com`:
run **Product > Test** on a simulator. It checks the real WebSocket redirect path,
Access discovery and password preservation without completing GitHub login.
Simulator tests need normal ad-hoc signing enabled for Keychain access.

## License

MIT
