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

if grep -q 'PASTE_YOUR_PUBLIC_KEY_LINE_HERE' user-data; then
  die "You haven't added your SSH key yet.

  1. Print your key:      cat ~/.ssh/id_ed25519.pub
     (No such file? Make one:  ssh-keygen -t ed25519 -C \"dev vm\"
      then press Return three times.)

  2. Open the file:       open -e cloud-init/user-data

  3. Paste your key over the words PASTE_YOUR_PUBLIC_KEY_LINE_HERE,
     keeping the '      - ' at the start, so the line reads:

         - ssh-ed25519 AAAAC3Nza... you@yourmac

  4. Save with Cmd+S, then run this script again."
fi

# Pull out the key line so we can inspect it properly. Everything after the
# leading '- ' is what actually lands in authorized_keys on the VM.
KEYLINE=$(grep -E '^[[:space:]]+- (ssh-|ecdsa-)' user-data | head -1 | sed 's/^[[:space:]]*-[[:space:]]*//')

[[ -n "$KEYLINE" ]] || die "No SSH key found in user-data.

The key line must start with '      - ' followed by your key, like:
      - ssh-ed25519 AAAAC3Nza... you@yourmac

Check that you pasted the whole line from 'cat ~/.ssh/id_ed25519.pub'."

KEYTYPE=$(printf '%s' "$KEYLINE" | awk '{print $1}')
KEYBLOB=$(printf '%s' "$KEYLINE" | awk '{print $2}')

# The classic mistake: pasting the whole key ON TOP OF an existing 'ssh-ed25519'
# prefix, giving '- ssh-ed25519 ssh-ed25519 AAAA...'. sshd rejects that, and the
# only symptom is 'Permission denied (publickey)' days later. Catch it here.
case "$KEYBLOB" in
  ssh-*|ecdsa-*)
    die "Your key type appears TWICE on the same line:

    $(printf '%.70s' "$KEYLINE")...

Delete the first '$KEYTYPE ' so the line starts with the key type exactly
once, then run this script again. It should look like:

      - ssh-ed25519 AAAAC3Nza... you@yourmac"
    ;;
esac

# A real key's second field is base64 and always starts with AAAA.
case "$KEYBLOB" in
  AAAA*) ;;
  *) die "That doesn't look like a valid SSH public key:

    $(printf '%.70s' "$KEYLINE")...

The part after '$KEYTYPE' should be a long string starting with AAAA.
Re-copy the ENTIRE output of:  cat ~/.ssh/id_ed25519.pub"
    ;;
esac

# Final authority: let ssh-keygen parse it the way sshd will.
printf '%s\n' "$KEYLINE" > "$PWD/.keycheck.tmp"
if ! ssh-keygen -l -f "$PWD/.keycheck.tmp" >/dev/null 2>&1; then
  rm -f "$PWD/.keycheck.tmp"
  die "ssh-keygen can't read your key, so the VM won't accept it either:

    $(printf '%.70s' "$KEYLINE")...

Re-copy the ENTIRE output of:  cat ~/.ssh/id_ed25519.pub"
fi
rm -f "$PWD/.keycheck.tmp"
ok "SSH key looks valid ($KEYTYPE)"

# A single Tab makes the VM silently ignore this whole file, so catch it here.
if grep -q "$(printf '\t')" user-data; then
  die "user-data contains a Tab character. YAML does not allow tabs.
Open the file and replace any tabs with spaces."
fi
ok "no tab characters"

head -1 user-data | grep -q '^#cloud-config' \
  || die "The first line of user-data must be exactly: #cloud-config"
ok "header looks right"

if grep -q 'password: "changeme"' user-data; then
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
