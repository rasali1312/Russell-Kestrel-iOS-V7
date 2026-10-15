# Russell Kestrel iOS V7 — archive search repair

This repair stage connects the SwiftUI Playback screen to the Kestrel DVR's HTTP/XML CGI endpoint (`/tdkcgi`) and attempts the legacy plain-XML archive commands identified in the working Windows Playback JavaScript:

- `g.rec.session` — create a recording-search session for the selected time range and channels.
- `g.rec.msg` — fetch the recording metadata for that session.
- Parse channel, start/end time, filename, record type and size returned by the DVR.

Playback now automatically searches the selected day/time range on entry, shows per-camera counts, and lists matching recording segments. The date/time controls can be changed and searched again. The app does not record on the phone and does not substitute live RTSP for archive video.

## Important limitation

This is a real archive-search implementation attempt, **not yet a verified end-to-end video playback fix**. The Windows page launches archive media using the proprietary `quii://.../mode=file&type=rec&filename=...` transport and calls ActiveX `ITransformToPlaybackXml` to decode some newer `*Ex` responses. That proprietary media transport/transform is not included in this source and is not a standard AVPlayer URL. The app will report an explicit error if the DVR returns a response it cannot decode, rather than claim that video is playing.

The project must be built and tested against the actual DVR firmware using GitHub Actions/Xcode. This environment does not have Xcode or access to the user's private DVR network, so the archive request cannot be live-verified here.

## Build

Use the included `.github/workflows/unsigned-ipa.yml` workflow (`workflow_dispatch`) to build an unsigned IPA in GitHub Actions.
