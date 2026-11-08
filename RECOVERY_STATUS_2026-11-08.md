# Russell Kestrel iOS V7 — recovery status, 8 November 2026

## Confirmed
- The 3 November `live-gestures` unsigned build (run 41734950406) compiles but is NOT validated for live camera playback or DVR HDD playback.
- `KestrelConfiguration.host` was empty by default, causing all Live WKWebViews to have nil URLs until the user manually set a host.
- Settings were persisted in UserDefaults, so merely introducing a nonempty default would not help already installed versions with a saved blank host.
- The Live grid/zoom still loads the old DVR HTTP page in WKWebView. That does NOT provide a native iOS decoder for the proprietary DVR live transport or its legacy browser plugin. Automatic login for Live is not implemented.
- Playback archive search is incomplete and recorded video playback is not implemented. Do not represent this as a finished playback app.

## Changes in this recovery branch
- Default Kestrel remote host now uses the previously established public DVR address `82.45.245.21` (web `8081`, RTSP `8554` are unchanged).
- On startup an existing saved configuration with empty host is repaired, preserving saved username, password and other values.

## Important caveat
These two changes fix only connection configuration. **They do not fix live video decoding, login or playback.** This branch is not to be distributed as a working release.

## Next engineering dependency
Obtain a known-working earlier iOS Live implementation and its source, or validate a standards-based DVR stream or mobile-compatible video bridge. Without an actual playable media transport and iPhone runtime tests, green CI builds are not acceptance evidence. Work on archive playback in a separate branch after Live has been restored.

## Existing candidate to compare against
Pre-gestures workflow run 39140027863, 18 October 2026, unsigned artifact 12141625953. This is a reference candidate, not verified working.
