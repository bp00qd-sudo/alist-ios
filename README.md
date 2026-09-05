# Alist iOS

This repository contains an iOS host for the upstream [Alist](https://github.com/AlistGo/alist) server.
The original Alist web application is served by an embedded Go runtime and loaded in a native
SwiftUI/WKWebView shell. The default local endpoint is `http://127.0.0.1:5244`; LAN access can be
enabled from the app.

The upstream source is pinned under [`alist/`](alist) at commit
`e1c022a9d920559078e5a906d7e1499901857006`. The repository intentionally keeps the Go module
separate from the iOS host so upstream updates can be reviewed and merged independently.

## Build on macOS

Requirements: Xcode 15+, Go 1.25+, and `gomobile`.

```sh
./scripts/fetch-web-dist.sh
./scripts/build-ios.sh
open ios/AlistApp/AlistApp.xcodeproj
```

The build script creates `build/AlistCore.xcframework` and copies it into the Xcode project.
The IPA export is intentionally manual because the signing identity and provisioning profile belong
to the device owner. See [`docs/ios-build.md`](docs/ios-build.md) for self-signing and background
mode notes.

Alist is licensed under AGPL-3.0. Keep the license, notices, and corresponding source when
redistributing a signed build.
