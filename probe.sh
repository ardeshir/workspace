#!/usr/bin/env bash
#
# probe.sh — list what is installed on an EXISTING machine.
#
# You only need this if you are the person SHARING a VM and you want to know
# what to put in provision.sh. If you are setting up a new VM, ignore this file.
#
# RUN THIS INSIDE THE MACHINE YOU WANT TO COPY:
#
#   ./probe.sh > my-setup.txt
#
# It only reads. It installs nothing and changes nothing.
#
set -uo pipefail

hr() { printf '\n===== %s =====\n\n' "$1"; }

hr "SYSTEM"
uname -a
[ -f /etc/os-release ] && grep PRETTY_NAME /etc/os-release

hr "PACKAGES YOU INSTALLED YOURSELF"
# Everything manually installed, minus whatever the Ubuntu installer put there.
BASELINE=/var/log/installer/initial-status.gz
if [ -f "$BASELINE" ]; then
  comm -23 \
    <(apt-mark showmanual | sort) \
    <(gzip -dc "$BASELINE" | sed -n 's/^Package: //p' | sort)
else
  echo "(No installer baseline on this machine — showing ALL manually-marked"
  echo " packages instead. Most of these came with the system; skim for the"
  echo " ones you recognise as yours.)"
  echo
  apt-mark showmanual | sort
fi

hr "SNAPS"
command -v snap >/dev/null 2>&1 && snap list 2>/dev/null || echo "(snap not installed)"

hr "PYTHON PACKAGES"
command -v pip3  >/dev/null 2>&1 && pip3 list --user 2>/dev/null || echo "(no user pip packages)"
command -v pipx  >/dev/null 2>&1 && pipx list 2>/dev/null       || echo "(pipx not installed)"

hr "NODE"
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh"
  echo "nvm versions:"; nvm ls 2>/dev/null
  echo; echo "global npm packages:"; npm ls -g --depth=0 2>/dev/null
else
  command -v node >/dev/null 2>&1 && node --version || echo "(node not installed)"
  command -v npm  >/dev/null 2>&1 && npm ls -g --depth=0 2>/dev/null
fi

hr "OTHER RUNTIMES"
for c in docker rustc cargo go java python3 psql mysql redis-server nginx terraform kubectl helm aws az gcloud; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$c" "$("$c" --version 2>&1 | head -1)"
  fi
done

hr "THINGS THAT ARE EASY TO FORGET"
echo "--- config files changed in the last 180 days ---"
sudo find /etc -type f -mtime -180 2>/dev/null | grep -vE '/(ssl|ssh/ssh_host|cache)/' | head -40

echo
echo "--- services that were switched on ---"
systemctl list-unit-files --state=enabled --no-pager 2>/dev/null | head -40

echo
echo "--- scheduled jobs ---"
crontab -l 2>/dev/null || echo "(none for this user)"

echo
echo "--- dotfiles in your home directory ---"
ls -a "$HOME" 2>/dev/null | grep '^\.' | grep -vE '^\.(|\.|cache|local|bash_history|sudo_as_admin_successful)$'

printf '\n===== END =====\n\n'
echo "Now copy the interesting package names into the APT_PACKAGES list in"
echo "provision.sh, and set the INSTALL_DOCKER / INSTALL_RUST / INSTALL_GO"
echo "toggles to match. Leave out anything with secrets in it."
