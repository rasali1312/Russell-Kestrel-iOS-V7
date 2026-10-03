# Russell Kestrel iOS V7

Native iPhone/iPad project for the OYN-X Kestrel DVR.

## V7 changes
- Real iOS/iPadOS application target; no macOS target.
- No VLCKit dependency and no duplicate Info.plist.
- SwiftUI interface with Live and Playback sections.
- 16-channel architecture now; code is structured to extend to 32+.
- Five-camera current setup is naturally supported without hard-coding five channels.
- Playback is intended to use the Kestrel DVR web interface/HDD archive rather than recording on the phone.
- Audio session scaffolding for live/archive audio and optional two-way talk.
- Settings for DVR host, web port (default 8081), RTSP port (default 8554), credentials and channel capacity.

## Important
The Kestrel DVR's exact playback request/API is vendor firmware-specific. V7 deliberately keeps that protocol behind the web playback layer so the next step can plug in the exact request captured from the working Edge playback page without changing the UI or channel architecture.

## Build
Open `RussellKestrel.xcodeproj` in Xcode 26 and select an iPhone or iPad destination. For an unsigned CI build use the included GitHub Actions workflow.
