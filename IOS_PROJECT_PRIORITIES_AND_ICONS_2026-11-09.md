# iOS project boundaries and deliverable requirements — 9 November 2026

## Strict priority (user-directed)
1. Russell IP Camera iOS — FIRST: fix version 8.0 (11). Camera Live video currently works; SD recordings playback with sound currently works. PRESERVE both. Fix Siren HTTP 400, microphone/Talk blocked by AAC indication, camera original page showing black legacy-plugin screen, and WAN-port/codec diagnostic inconsistencies. Exact source for installed 8.0 (11) still to identify before changing runtime files.
2. Russell Kestrel (Castle) iOS V7 — SECOND: repair 9-channel Live showing OYN-X web splash instead of video and repair DVR HDD Playback failure (g.rec.msg XML reply not parsed, video playback missing). Treat as separate app.
3. Russell Viewer iOS — LAST, FROZEN: preserve the working Live grid for nine cameras, tap to fullscreen, zoom, camera switching and sound. HDD Playback is unfinished but do not modify this project until the first two are fixed, so the user always has a working phone viewer.

## Mandatory distinct embedded app icons — no manual work for friend
- EVERY app must have its own distinct, finished original eagle/camera-related icon, visually identifying **Russell IP Camera iOS**, **Russell Kestrel iOS V7**, or **Russell Viewer iOS**.
- Each Xcode target must include its complete iOS AppIcon asset inside `Assets.xcassets/AppIcon.appiconset` (or equivalent project target asset catalog), with applicable iPhone/iPad icon size representations and a correct `Contents.json`. Use correctly sized PNG(s), including 1024x1024 marketing master where appropriate; no missing / external / manually copied images.
- `ASSETCATALOG_COMPILER_APPICON_NAME` must point to `AppIcon`; project resources and target build phases must include the asset catalog. Confirm a compiled IPA's Assets.car and icon metadata, plus the distinct display name and CFBundleIdentifier, before handing over.
- Each of the THREE apps must use a UNIQUE bundle identifier so signing/install cannot overwrite a different project. This is especially important because Russell IP Camera accidentally replaced Kestrel V7 in an earlier installation.
- The friend should only need to open the complete project, select signing Team, build/install. He must NOT create/edit/replace the icon.
- Do not treat a screenshot, a generated image or a design plan as proof that assets have actually been embedded in the executable. Do not send a final build until verified.
- Protect the user's already-working Russell Viewer installation and its icon; do not install anything over it during repair.

## GitHub tracking
IP camera iOS issue: https://github.com/rasali1312/Russell-IP-Camera-IOS-for-IPHONE-IPAD/issues/2
Kestrel V7 issue: https://github.com/rasali1312/Russell-Kestrel-iOS-V7/issues/1

## Delivery acceptance
Do not claim device functionality just because GitHub Actions compiled. A real iPhone test must demonstrate rendered frames, archival footage and sound where expected, and audible mic-to-camera speech where applicable. Maintain isolated code and release zip per project. Never commit camera passwords or replace working versions blindly.

## This repository
Second priority. Fix Live and HDD Playback only after IP Camera iOS.
