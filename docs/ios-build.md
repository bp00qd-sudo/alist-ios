# iOS build and runtime notes

## Runtime

`alist/iosbridge` is the only Go package imported by the native host. It converts the process-oriented
Alist startup into a start/stop-able runtime and exposes a small gomobile-friendly API. The JSON
options object is deliberately version-tolerant:

```json
{
  "dataDir": "/var/mobile/Containers/Data/Application/<uuid>/Library/Alist",
  "tempDir": "/var/mobile/Containers/Data/Application/<uuid>/Library/Caches/Alist",
  "lanEnabled": false,
  "port": 5244,
  "s3": false,
  "ftp": false,
  "sftp": false,
  "memoryLimitBytes": 100663296
}
```

The Go runtime never creates a daemon or calls `os.Exit`. FTP and SFTP are opt-in because they add
listeners and connection state to the process. The HTTP API (including WebDAV and optional S3 routing)
always remains on port 5244.

## Build the XCFramework

Run on macOS with an iOS SDK installed:

```sh
brew install go
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
./scripts/fetch-web-dist.sh
./scripts/build-ios.sh
```

The script runs an `ios/arm64` build with `-tags=ios`, `-trimpath`, and stripped linker symbols. It
also writes `build/ios-driver-compatibility.json`, which records the result of the compile probe for
the complete upstream driver set. Drivers that need FUSE, WinAPI, or an external executable are kept
in the registry but return `unsupported on iOS` when selected.

## Self-signing

Open `ios/AlistApp/AlistApp.xcodeproj`, select a personal team, choose a unique bundle identifier,
and enable automatic signing. Archive with a connected arm64 device, then export an iOS App Store
package or development IPA using the generated provisioning profile. A personal provisioning profile
may expire quickly; this is an Apple signing limitation rather than an Alist limitation.

## Background behavior

The app schedules resumable `BGProcessingTask` work and uses background `URLSession` transfers where
possible. The optional audio/location keep-alive mode is experimental, opt-in, battery intensive, and
still subject to iOS suspension or termination. Every transfer is persisted by Alist's SQLite task
store so a later foreground launch can resume it.

## Memory budget

The embedded runtime starts with a 96 MiB Go memory limit, two Go processors, four total concurrent
operations, one worker per task class, 64 KiB stream buffers, and no automatic Bleve index build. Use
Instruments Allocations/VM Tracker on a real device. The regression target is a combined steady-state
foreground footprint of 150 MiB for idle, large-directory, preview, and ordinary transfer scenarios.
