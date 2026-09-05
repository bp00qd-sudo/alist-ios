#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
go_root="$repo_root/alist"
out_dir="$repo_root/build"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-ios.sh must run on macOS (Xcode is required)." >&2
  exit 2
fi
command -v xcodebuild >/dev/null || { echo "Xcode is required" >&2; exit 2; }
command -v go >/dev/null || { echo "Go is required" >&2; exit 2; }
command -v gomobile >/dev/null || { echo "Install gomobile first: go install golang.org/x/mobile/cmd/gomobile@latest" >&2; exit 2; }

if [[ ! -f "$go_root/public/dist/index.html" ]]; then
  echo "Alist web assets are missing; run scripts/fetch-web-dist.sh first." >&2
  exit 2
fi

mkdir -p "$out_dir"
pushd "$go_root" >/dev/null
go mod download

# gopsutil's Darwin cgo files target macOS-only headers (libproc, SMC and
# mach APIs). The package already ships portable no-cgo implementations, so
# apply the small iOS build-tag patch before gomobile compiles dependencies.
gopsutil_dir="$(go list -m -f '{{.Dir}}' github.com/shirou/gopsutil/v3)"
patch_tmp="$out_dir/.patch-tmp"
mkdir -p "$patch_tmp"
TMPDIR="$patch_tmp" patch -N -p1 -d "$gopsutil_dir" < "$repo_root/patches/gopsutil-ios.patch" || {
  # A second local invocation is harmless when the patch was applied already.
  if ! grep -q '^//go:build darwin && cgo && !ios$' "$gopsutil_dir/cpu/cpu_darwin_cgo.go"; then
    echo "failed to apply gopsutil iOS compatibility patch" >&2
    exit 1
  fi
}

# Keep a machine-readable compatibility report even when the package list has
# errors. This is useful for identifying desktop-only drivers on a new commit.
go list -e -tags=ios -f '{{if .Error}}{{.ImportPath}}: {{.Error.Err}}{{end}}' ./... \
  > "$out_dir/ios-driver-compatibility.txt" || true
go mod why -m github.com/shoenig/go-m1cpu \
  > "$out_dir/ios-m1cpu-why.txt" || true
cat "$out_dir/ios-m1cpu-why.txt"

gomobile bind \
  -target=ios/arm64 \
  -tags=ios \
  -trimpath \
  -ldflags='-s -w' \
  -o "$out_dir/AlistCore.xcframework" \
  ./iosbridge
popd >/dev/null

echo "Built $out_dir/AlistCore.xcframework"
