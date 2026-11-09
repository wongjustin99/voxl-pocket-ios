# Visual history

- `2026-11-09-05/`: toolbar safe-area baseline at `b0954ff`, captured on an iPhone 13 Pro simulator in portrait and landscape-left. An intentionally unreachable localhost host keeps private desktop content out of the screenshots.
- `2026-11-09-06/`: toolbar anchored inside the safe area in portrait and both landscape orientations, from the safe-area fix containing this entry. Same simulator and host as the baseline. Layout regression failed before the fix and passes afterward. Signed device build succeeds; update installed and launched on Gattleskit after it reconnected.

- `2026-11-09-04/`: tapping an unconfigured Access host automatically opens the real GitHub sign-in page through `voxl.mailwong.com` on the iPad simulator. From the automatic Access-discovery fix containing this entry. No credentials entered; authenticated return and desktop streaming remain unverified.

- `2026-11-09-03/`: native iPhone host picker on Gattleskit (iPhone 13 Pro), from the iPhone-support commit containing this entry. Physical-device signed build, installation and launch succeeded. Status/navigation-return area cropped; no server is configured yet.

- `2026-11-09-01/`: upstream host picker at `bf8248dcbe4862c370dce55eff747e0ce9210f6c`, reconstructed from an unmodified upstream build.
- `2026-11-09-02/`: Cloudflare Access host action and sign-in prompt, from the implementation commit containing this entry. Same iPad Pro 11-inch (M5) simulator and example host as the baseline. The login sheet, TLS-error handling and cancellation were checked; a real GitHub/Cloudflare login has not yet been tested.
