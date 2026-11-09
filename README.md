# voxl-pocket-ios

A native iPhone and iPad client for [voxl](https://github.com/tembo/voxl), the low-latency remote
desktop server.

## Features

- H.264 video decoded in hardware (AVSampleBufferDisplayLayer), one layer per stripe
- Trackpad, touch and view-only modes, with settings saved per computer
- Tap-and-drag, three-finger drag, right and middle mouse gestures, precision mouse circle
- Pinch to zoom, two-finger scroll and three-finger tap to toggle the keyboard
- Hardware keyboards and mice, plus the soft keyboard with a key bar for Esc, Tab,
  sticky Shift/Cmd/Ctrl/Opt, ⌘Space, ⌘Tab and arrows
- Keeps the host at its own resolution by default; can resize it to fit the iPad
  (Large, Medium, More space) when the server runs with `--enable-resize`
- Switch between the host's displays
- Clipboard both ways, text and images
- Split View, Slide Over and any orientation
- Remote controls stay clear of the notch and Dynamic Island in portrait and landscape

## Use

Tap **+** and enter the server's address, for example `wss://my-mac.example.com:6901/ws`,
and its password. The password is stored in the iOS Keychain.

Tap the input icon at the top right to choose **Trackpad mode**, **Touch mode**, or
**View only**. The same menu controls the precision mouse circle and scroll direction.
These settings are saved separately for each computer.

### Gestures

| Action | Gesture |
| --- | --- |
| Left click / double click | Tap / double tap |
| Left drag without a hold delay | Tap, touch again, then move without lifting |
| Left drag in trackpad mode | Drag with three fingers, or hold one finger then move |
| Right click | Tap with two fingers; in touch mode, a single hold also right-clicks |
| Right drag | Tap, touch again and hold until the ring appears, then move |
| Middle click or drag | Tap twice, touch again and hold until the ring appears; release to click or move to drag |
| Show or hide the keyboard | Tap with three fingers |
| Scroll / zoom | Move two fingers / pinch |

Trackpad gestures act at the pointer. Slow movements keep fine control; fast swipes
move the pointer up to twice as far, including while dragging. The precision
circle keeps its fixed, slow movement speed. Touch mode acts at your finger. Lift to drop a
dragged item. Holds take about 0.4 seconds. The optional precision circle moves the
pointer more slowly and supports the same one-finger click and drag gestures.

**View only** blocks mouse, keyboard, clipboard sync and desktop resizing from this
client. You can still zoom and pan locally with two fingers. This is a local input
lock, not a replacement for server-side access controls.

### Cloudflare Tunnel with Access (GitHub login)

Point the tunnel's public hostname at the Voxl server's local HTTP port, and add that
hostname to Voxl's `--allowed-hosts`. Keep your existing Cloudflare Access policy.

1. Add `wss://desktop.example.com/ws` as a host. Its password is the **Voxl password**,
   not your GitHub password.
2. Tap the saved host. A Cloudflare Access login redirect automatically opens sign-in.
   You can also swipe left, tap **Access**, then **Sign In** to log in manually.
3. Complete Cloudflare's GitHub login in Apple's Safari sheet. Passkeys and enabled
   password-manager extensions are available. The sheet closes and the native desktop
   connects automatically after sign-in.

The app uses Cloudflare's encrypted CLI token-transfer flow to retrieve the application
Access token without reading Safari's cookies. Each attempt uses a new ephemeral NaCl
key pair. Only the application token is saved in the Keychain, scoped to the exact
hostname and port, until its expiry; the organization token is discarded. The token
is sent in `CF-Access-Token`, not a browser cookie. Before saving it, the app checks
that the host does not redirect it back to Access or reject it with HTTP 403/5xx.
A rejected token shows an error instead of reconnecting. No Voxl password is sent to
the browser or this check. Cancel closes sign-in and stops the transfer request.
Safari manages the identity-provider session; deleting a host or turning off Access
in the app does not sign you out of the browser. Policies that require a browser-only
binding cookie may not support this CLI flow.

When Access expires or rejects a connection, tap the desktop's sign-in message to
log in again. A 403 does not erase the saved Voxl password. To stop using Access for a
host, swipe left, tap **Access**, then **Turn Off in App**; this does not change the
server's Cloudflare policy. Deleting a host removes its saved password and Access cookies.

The real GitHub/Access flow must be tested against your protected hostname; local
unit tests do not validate your Access policy or identity-provider configuration.

## Privacy

Voxl Pocket collects no data and has no analytics, ads or accounts. The servers you add
are stored on your device, and their passwords in the iOS Keychain. The app talks to
the servers you add: it sends your input, and your clipboard when it changes, and receives
the screen and the server's clipboard. When you enable Cloudflare Access, the sign-in
sheet also contacts Cloudflare and your chosen identity provider (such as GitHub).
The app retrieves the encrypted application token from `login.cloudflareaccess.org`
and saves it in the Keychain, not your GitHub password or organization token.
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

Run the cookie-scoping, handshake-error and encrypted-transfer tests with `swift test`.
The build resolves the pinned Swift Sodium dependency for Cloudflare's NaCl protocol.
The Xcode scheme also includes a live integration test against `voxl.mailwong.com`:
run **Product > Test** on a simulator. It checks the real WebSocket redirect path,
Access discovery and password preservation without completing GitHub login.
Simulator tests need normal ad-hoc signing enabled for Keychain access.

For wire-level gesture checks without controlling a desktop, run the loopback fixture:

```sh
uv run scripts/input-replay-server.py --output /tmp/voxl-input-replay.jsonl
```

Add `ws://localhost:6922/ws` in the simulator with a dummy password. The fixture sends
screen dimensions but no video, records pointer/button/scroll events, and redacts
keyboard and clipboard text. It never captures a screen or injects input. Automated
checks cover one- and two-finger input; the device driver cannot synthesize three
fingers, so three-finger tap/drag still need a physical-device check.

## License

MIT
