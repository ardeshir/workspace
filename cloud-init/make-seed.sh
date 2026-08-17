#!/usr/bin/env bash
#
# make-seed.sh — build seed.iso from user-data and meta-data.
#
# RUN THIS ON YOUR MAC.
#
#   ./cloud-init/make-seed.sh
#
# seed.iso is a small disc you attach to the VM. The VM reads your settings
# off it on first boot, then never needs it again.
#
# Re-run this after any edit to user-data or meta-data.
#
set -euo pipefail

BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; OFF=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$OFF"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$OFF" "$1"; }
die()  { printf '\n%sERROR:%s %s\n\n' "$RED" "$OFF" "$1" >&2; exit 1; }

cd "$(dirname "${BASH_SOURCE[0]}")"

[[ "$(uname -s)" == "Darwin" ]] || die "Run this on your Mac, not inside the VM."
[[ -f user-data ]] || die "Can't find user-data next to this script."
[[ -f meta-data ]] || die "Can't find meta-data next to this script."

# --- catch the mistakes people actually make ---------------------------------

step "Checking user-data"

if grep -q 'REPLACE_WITH_YOUR_PUBLIC_KEY' user-data; then
  die "You haven't added your SSH key yet.

  1. Print your key:      cat ~/.ssh/id_ed25519.pub
     (No such file? Make one:  ssh-keygen -t ed25519 -C \"dev vm\"
      then press Return three times.)

  2. Open the file:       open -e cloud-init/user-data

  3. Replace the line
         - ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY
     with your key, keeping the '      - ' at the start.

  4. Save with Cmd+S, then run this script again."
fi

grep -qE '^[[:space:]]+- (ssh-ed25519|ssh-rsa|ecdsa-) ' user-data \
  || die "No valid SSH key found in user-data.

The key line must start with '      - ' followed by ssh-ed25519 or ssh-rsa.
Check that you pasted the whole line from 'cat ~/.ssh/id_ed25519.pub'."
ok "SSH key present"

# A single Tab makes the VM silently ignore this whole file, so catch it here.
if grep -q "$(printf '\t')" user-data; then
  die "user-data contains a Tab character. YAML does not allow tabs.
Open the file and replace any tabs with spaces."
fi
ok "no tab characters"

head -1 user-data | grep -q '^#cloud-config' \
  || die "The first line of user-data must be exactly: #cloud-config"
ok "header looks right"

if grep -q 'dev:changeme' user-data; then
  warn "password is still 'changeme' — fine to start with, but worth changing"
fi

# --- build -------------------------------------------------------------------

step "Building seed.iso"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp user-data meta-data "$STAGING/"

rm -f seed.iso

# The volume MUST be named CIDATA — that is how the VM finds these settings.
# hdiutil ships with macOS, so there is nothing to install.
hdiutil makehybrid \
  -o seed.iso \
  -iso -joliet \
  -default-volume-name CIDATA \
  "$STAGING" >/dev/null

[[ -f seed.iso ]] || die "seed.iso was not created. Unexpected — please report this."
ok "seed.iso created ($(du -h seed.iso | cut -f1 | tr -d ' '))"

cat <<EOF

$GREEN$BOLD Done.$OFF

 You now have both files you need, inside the cloud-init folder:
   ubuntu.img    the Ubuntu disk
   seed.iso      your settings

 Next: open UTM and follow ${BOLD}Path B, Step 5${OFF} in the README.

 Changed your mind about something in user-data? Edit it, run this script
 again, and — if the VM already exists — also bump ${BOLD}instance-id${OFF} in
 meta-data so the VM knows to re-read its settings.

EOF
