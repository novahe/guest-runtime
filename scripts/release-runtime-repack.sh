#!/usr/bin/env bash
# release-runtime-repack: build runtime-repack for both architectures and
# package the binaries as one deterministic tarball laid out
# guest-runtime/<arch>/runtime-repack, ready to copy to a node and extract.
set -euo pipefail
umask 022

TOOL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TOOL_ROOT"

GO="${GO:-go}"
STAGE="$(mktemp -d)"
trap 'chmod -R u+w "$STAGE"; rm -rf "$STAGE"' EXIT

build() {
  local target_arch="$1" go_arch="$2"
  mkdir -p "bin/$target_arch" "$STAGE/guest-runtime/$target_arch"
  GOOS=linux GOARCH="$go_arch" CGO_ENABLED=0 "$GO" build \
    -trimpath -ldflags '-s -w' \
    -o "bin/$target_arch/runtime-repack" ./cmd/runtime-repack
  cp "bin/$target_arch/runtime-repack" "$STAGE/guest-runtime/$target_arch/runtime-repack"
}

build x86_64 amd64
build aarch64 arm64

# Deterministic archive: sorted entries, root ownership, zero mtime, no
# gzip timestamp — identical inputs rebuild to a byte-identical tarball.
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 \
  --pax-option=delete=atime,delete=ctime -cf - -C "$STAGE" guest-runtime \
  | gzip -n > bin/runtime-repack.tar.gz

sha256sum bin/runtime-repack.tar.gz
