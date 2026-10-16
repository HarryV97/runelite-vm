#!/usr/bin/env bash
# One-shot setup on a fresh Debian 13 (trixie) machine/VM, x86_64, no desktop.
#
#   sudo ./setup.sh                          # install everything, no instance yet
#   sudo ./setup.sh main 1                   # ...and create instance "main" (web login on)
#   sudo ./setup.sh main 1 --no-login        # ...without a web login
#
# Safe to re-run (e.g. to update the kiosk files after a git pull).
set -euo pipefail
cd "$(dirname "$0")"

KASMVNC_VERSION=1.5.0
BOLT_APP=com.adamcake.Bolt

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run with sudo: sudo ./setup.sh"
[[ $(dpkg --print-architecture) == amd64 ]] || die "x86_64 (amd64) only; Bolt isn't built for other CPUs"
. /etc/os-release
codename=${VERSION_CODENAME:-}
case $codename in
	trixie) ;;
	bookworm) echo "warning: built and tested on Debian 13 (trixie); trying Debian 12 (bookworm)" ;;
	*) die "needs Debian 13 (trixie); this is '${PRETTY_NAME:-unknown}'" ;;
esac

say "Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
	curl ca-certificates openbox xauth dbus-x11 dbus-user-session x11-xserver-utils xdotool \
	flatpak fonts-dejavu-core fontconfig x11-apps netpbm >/dev/null

if dpkg -s kasmvncserver 2>/dev/null | grep -q "^Version: $KASMVNC_VERSION"; then
	say "KasmVNC $KASMVNC_VERSION already installed"
else
	say "Installing KasmVNC $KASMVNC_VERSION"
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	deb="kasmvncserver_${codename}_${KASMVNC_VERSION}_amd64.deb"
	curl -fsSL -o "$tmp/$deb" "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/$deb" ||
		die "couldn't download $deb"
	apt-get install -y -qq "$tmp/$deb" >/dev/null
fi

say "Installing Bolt launcher (Flatpak, ~1.2 GB the first time)"
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
if flatpak info --system "$BOLT_APP" >/dev/null 2>&1; then
	flatpak update --system -y --noninteractive "$BOLT_APP" >/dev/null || true
else
	flatpak install --system -y --noninteractive flathub "$BOLT_APP"
fi

say "Installing kiosk files"
./install.sh

if [[ $# -ge 2 ]]; then
	say "Creating instance '$1'"
	add-instance "$@"
else
	say "Done"
	echo "Create your first instance:  sudo add-instance main 1            (asks for a web password)"
	echo "                         or: sudo add-instance main 1 --no-login (no web password)"
fi
