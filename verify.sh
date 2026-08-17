#!/usr/bin/env bash
#
# verify.sh — check that everything provision.sh installed actually works.
#
# RUN THIS INSIDE THE VM:
#
#   ./verify.sh
#
# ✓ = working    · = not installed (fine if you turned it off)    ✗ = broken
#
set -uo pipefail   # deliberately no -e: we want to report every problem, not stop at the first

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

# Make the tools visible even in a shell that hasn't loaded .bashrc yet.
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
# shellcheck disable=SC1091
[ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -d /usr/local/go/bin ] && export PATH="$PATH:/usr/local/go/bin"

FAILED=0

# check <label> <command> <version-command> <required|optional>
check() {
  local label="$1" cmd="$2" vercmd="$3" need="${4:-required}"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver=$(eval "$vercmd" 2>/dev/null | head -1)
    printf '  %s✓%s %-12s %s\n' "$GREEN" "$OFF" "$label" "${ver:-installed}"
  elif [[ "$need" == "optional" ]]; then
    printf '  %s·%s %-12s not installed\n' "$YELLOW" "$OFF" "$label"
  else
    printf '  %s✗%s %-12s MISSING\n' "$RED" "$OFF" "$label"
    FAILED=$((FAILED + 1))
  fi
}

printf '\n%sChecking your VM%s\n\n' "$BOLD" "$OFF"

check git   git   'git --version'
check curl  curl  'curl --version'
check jq    jq    'jq --version'
check rg    rg    'rg --version'
check gcc   gcc   'gcc --version'
check python3 python3 'python3 --version'
check node  node  'node --version'
check npm   npm   'npm --version'
check rustc rustc 'rustc --version' optional
check go    go    'go version'      optional

# Docker needs more than "is it installed" — it must work without sudo.
printf '\n'
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    printf '  %s✓%s %-12s %s\n' "$GREEN" "$OFF" "docker" "$(docker --version)"
  elif id -nG "$USER" | grep -qw docker; then
    printf '  %s✗%s %-12s installed, but not usable yet\n' "$RED" "$OFF" "docker"
    printf '      You are in the docker group but this session started before that.\n'
    printf '      Fix: type %sexit%s, then ssh back in, then run ./verify.sh again.\n' "$BOLD" "$OFF"
    FAILED=$((FAILED + 1))
  else
    printf '  %s✗%s %-12s installed, but you are not in the docker group\n' "$RED" "$OFF" "docker"
    printf '      Fix: sudo usermod -aG docker $USER  — then log out and back in.\n'
    FAILED=$((FAILED + 1))
  fi
else
  printf '  %s·%s %-12s not installed\n' "$YELLOW" "$OFF" "docker"
fi

# Disk space — the usual cause of confusing build failures later.
printf '\n'
AVAIL=$(df -h / | awk 'NR==2 {print $4}')
PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [[ "${PCT:-0}" -ge 90 ]]; then
  printf '  %s✗%s %-12s only %s free (%s%% used)\n' "$RED" "$OFF" "disk" "$AVAIL" "$PCT"
  FAILED=$((FAILED + 1))
else
  printf '  %s✓%s %-12s %s free\n' "$GREEN" "$OFF" "disk" "$AVAIL"
fi

printf '\n'
if [[ "$FAILED" -eq 0 ]]; then
  printf '%s%s All good — your VM is ready to use.%s\n\n' "$GREEN" "$BOLD" "$OFF"
  exit 0
else
  printf '%s%s %d problem(s) found.%s\n' "$RED" "$BOLD" "$FAILED" "$OFF"
  printf ' Try running ./provision.sh again — it is safe to repeat and usually fixes this.\n'
  printf ' If a problem sticks around, copy this output to whoever shared the repo with you.\n\n'
  exit 1
fi
