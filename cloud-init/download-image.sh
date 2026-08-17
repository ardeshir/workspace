#!/usr/bin/env bash
#
# download-image.sh — download the official Ubuntu 24.04 disk for Apple Silicon
# and check that it arrived intact.
#
# RUN THIS ON YOUR MAC.
#
#   ./cloud-init/download-image.sh
#
# Downloads about 600 MB into cloud-init/ubuntu.img. Safe to re-run: if the
# file is already there and correct, it does nothing.
#
set -euo pipefail

BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; OFF=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$OFF"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$OFF" "$1"; }
die()  { printf '\n%sERROR:%s %s\n\n' "$RED" "$OFF" "$1" >&2; exit 1; }

cd "$(dirname "${BASH_SOURCE[0]}")"

BASE="https://cloud-images.ubuntu.com/noble/current"
IMAGE="noble-server-cloudimg-arm64.img"
OUT="ubuntu.img"

# --- sanity checks -----------------------------------------------------------

[[ "$(uname -s)" == "Darwin" ]] || die "Run this on your Mac, not inside the VM."

if [[ "$(uname -m)" != "arm64" ]]; then
  die "This script is for Apple Silicon Macs (M1/M2/M3/M4).

Your Mac reports '$(uname -m)', which means it's an older Intel Mac.
This setup won't work there. Ask whoever shared this repo with you for the
Intel instructions."
fi
ok "Apple Silicon Mac detected"

FREE_GB=$(df -g . | awk 'NR==2 {print $4}')
if [[ "${FREE_GB:-99}" -lt 5 ]]; then
  die "Only ${FREE_GB} GB free on this disk. You need at least 5 GB here
(and about 30 GB total once the VM is running). Free up some space first."
fi

# --- fetch the official checksums -------------------------------------------

step "Fetching official checksums"
curl -fsSL -o SHA256SUMS "$BASE/SHA256SUMS" \
  || die "Couldn't reach $BASE — check your internet connection."
EXPECTED=$(awk -v f="*$IMAGE" '$2 == f {print $1}' SHA256SUMS)
[[ -n "$EXPECTED" ]] || die "Couldn't find $IMAGE in the checksum list.
Ubuntu may have changed its layout. Ask whoever shared this repo with you."
ok "expected checksum: ${EXPECTED:0:16}..."

verify() {
  [[ -f "$OUT" ]] || return 1
  local actual
  actual=$(shasum -a 256 "$OUT" | awk '{print $1}')
  [[ "$actual" == "$EXPECTED" ]]
}

# --- skip if we already have a good copy -------------------------------------

if [[ -f "$OUT" ]]; then
  step "Found an existing $OUT — checking it"
  if verify; then
    ok "already downloaded and correct — nothing to do"
    rm -f SHA256SUMS
    echo
    echo " Next: ./cloud-init/make-seed.sh"
    echo
    exit 0
  fi
  warn "the existing file doesn't match — downloading a fresh copy"
  rm -f "$OUT"
fi

# --- download ----------------------------------------------------------------

step "Downloading Ubuntu (about 600 MB — this can take a few minutes)"
curl -fL --progress-bar -o "$OUT.part" "$BASE/$IMAGE" \
  || die "Download failed. Check your internet connection and re-run this script."
mv "$OUT.part" "$OUT"
ok "downloaded"

step "Verifying the download"
if ! verify; then
  rm -f "$OUT" SHA256SUMS
  die "The download is corrupted, so it has been deleted.
This is almost always a flaky network. Just run this script again."
fi
ok "checksum matches — the file is intact"
rm -f SHA256SUMS

cat <<EOF

$GREEN$BOLD Done.$OFF  Ubuntu disk saved as cloud-init/$OUT ($(du -h "$OUT" | cut -f1 | tr -d ' '))

 Next: ${BOLD}./cloud-init/make-seed.sh${OFF}
 (Edit cloud-init/user-data first if you haven't added your SSH key yet.)

EOF
