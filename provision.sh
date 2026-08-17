#!/usr/bin/env bash
#
# provision.sh — install the development tools inside the VM.
#
# RUN THIS INSIDE THE VM (not on your Mac):
#
#   ./provision.sh
#
# It is safe to run more than once. Anything already installed is skipped,
# so if it stops halfway you can just run it again.
#
set -euo pipefail

# ============================================================================
#  EDIT ME — change what gets installed
#
#  yes / no for the toggles. Add or remove package names from the list.
# ============================================================================

APT_PACKAGES=(
  build-essential   # compilers, make -- lots of things need this
  git
  curl
  wget
  unzip
  jq                # reads JSON on the command line
  ripgrep           # fast search, the 'rg' command
  tree
  htop
  tmux
  vim
  python3-pip
  python3-venv
  ca-certificates
)

NODE_VERSION="lts/*"     # "lts/*" = newest long-term-support Node
INSTALL_DOCKER=yes
INSTALL_RUST=no
INSTALL_GO=no
GO_VERSION="1.23.4"      # only used when INSTALL_GO=yes

# ============================================================================
#  You shouldn't need to change anything below this line.
# ============================================================================

BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; OFF=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "$BOLD" "$1" "$OFF"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
skip() { printf '  %s·%s %s\n' "$YELLOW" "$OFF" "$1"; }
die()  { printf '\n%sERROR:%s %s\n\n' "$RED" "$OFF" "$1" >&2; exit 1; }

# --- guards ------------------------------------------------------------------

if [[ "$(uname -s)" == "Darwin" ]]; then
  die "This runs INSIDE the VM, not on your Mac.

Connect to the VM first:   ssh dev@<the VM's IP address>
Then run ./provision.sh there."
fi

if [[ "$(id -u)" -eq 0 ]]; then
  die "Don't run this with sudo or as root.

Run it as your normal user:   ./provision.sh
The script asks for your password itself when it needs to."
fi

command -v apt-get >/dev/null || die "This script expects Ubuntu or Debian."

# --- sudo, once --------------------------------------------------------------

step "Checking sudo access"
if ! sudo -n true 2>/dev/null; then
  echo "  You'll be asked for your VM password once. Typing shows nothing —"
  echo "  that's normal. Type it and press Return."
  sudo -v || die "Couldn't get sudo access."
fi
# Keep sudo awake so a long install doesn't stop to ask again.
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT
ok "sudo ready"

# --- apt packages ------------------------------------------------------------

step "Updating the package list"
sudo apt-get update -qq
ok "package list up to date"

step "Installing base packages"
MISSING=()
for pkg in "${APT_PACKAGES[@]}"; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    skip "$pkg (already installed)"
  else
    MISSING+=("$pkg")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "  installing: ${MISSING[*]}"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${MISSING[@]}"
  for pkg in "${MISSING[@]}"; do ok "$pkg"; done
fi

# --- docker ------------------------------------------------------------------

if [[ "$INSTALL_DOCKER" == "yes" ]]; then
  step "Installing Docker"
  if command -v docker >/dev/null 2>&1; then
    skip "docker (already installed)"
  else
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ok "docker installed"
  fi

  # Lets you run 'docker' without typing sudo every time.
  if id -nG "$USER" | grep -qw docker; then
    skip "already in the docker group"
  else
    sudo usermod -aG docker "$USER"
    ok "added you to the docker group"
    echo "     (takes effect after you log out and back in — verify.sh will tell you)"
  fi
else
  step "Docker"; skip "turned off in the EDIT ME section"
fi

# --- node via nvm ------------------------------------------------------------

step "Installing Node.js (via nvm)"
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  skip "nvm (already installed)"
else
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash >/dev/null
  ok "nvm installed"
fi
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"
if nvm ls "$NODE_VERSION" >/dev/null 2>&1; then
  skip "node $NODE_VERSION (already installed)"
else
  nvm install "$NODE_VERSION" >/dev/null
  ok "node $(node --version) installed"
fi
nvm alias default "$NODE_VERSION" >/dev/null 2>&1 || true

# --- rust --------------------------------------------------------------------

if [[ "$INSTALL_RUST" == "yes" ]]; then
  step "Installing Rust"
  if [[ -x "$HOME/.cargo/bin/rustc" ]]; then
    skip "rust (already installed)"
  else
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path >/dev/null
    ok "rust installed"
  fi
else
  step "Rust"; skip "turned off in the EDIT ME section"
fi

# --- go ----------------------------------------------------------------------

if [[ "$INSTALL_GO" == "yes" ]]; then
  step "Installing Go $GO_VERSION"
  if [[ -x /usr/local/go/bin/go ]] && /usr/local/go/bin/go version | grep -q "go$GO_VERSION"; then
    skip "go $GO_VERSION (already installed)"
  else
    TARBALL="go${GO_VERSION}.linux-arm64.tar.gz"
    curl -fsSL -o "/tmp/$TARBALL" "https://go.dev/dl/$TARBALL"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/$TARBALL"
    rm -f "/tmp/$TARBALL"
    ok "go $GO_VERSION installed"
  fi
else
  step "Go"; skip "turned off in the EDIT ME section"
fi

# --- shell setup -------------------------------------------------------------

step "Setting up your shell"
MARKER="# >>> dev vm setup >>>"
if grep -q "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
  skip ".bashrc (already set up)"
else
  cat >> "$HOME/.bashrc" <<'BASHRC'

# >>> dev vm setup >>>
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

[ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -d /usr/local/go/bin ] && export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"

# Show the current git branch in the prompt.
parse_git_branch() {
  git branch 2>/dev/null | sed -n 's/^\* \(.*\)/ (\1)/p'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '

alias ll='ls -alFh'
alias ..='cd ..'
alias gs='git status'
# <<< dev vm setup <<<
BASHRC
  ok ".bashrc updated (prompt, aliases, tool paths)"
fi

# --- done --------------------------------------------------------------------

cat <<EOF

$GREEN$BOLD Provisioning finished.$OFF

 Two more commands:

   1. Load the new settings into your current shell:

        ${BOLD}exec bash -l${OFF}

   2. Check that everything works:

        ${BOLD}./verify.sh${OFF}

EOF
