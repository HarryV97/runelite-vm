#!/usr/bin/env bash
# Installs/updates the kiosk files from this folder. Called by setup.sh; also run it on
# its own after changing anything here:  sudo ./install.sh
# Running instances pick up changes on their next restart (sudo systemctl restart runelite@<name>).
set -euo pipefail
cd "$(dirname "$0")"
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

install -d -m 755 /opt/runelite-kiosk /etc/runelite-kiosk
install -m 755 kiosk/xstartup kiosk/supervisor kiosk/bolt-capture kiosk/run-client /opt/runelite-kiosk/
install -m 644 kiosk/openbox-rc.xml kiosk/bolt-launcher.json kiosk/runelite-settings.properties /opt/runelite-kiosk/
install -m 755 add-instance remove-instance /usr/local/sbin/

[[ -f /etc/kasmvnc/kasmvnc.yaml.orig ]] || cp /etc/kasmvnc/kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml.orig
install -m 644 kiosk/kasmvnc.yaml /etc/kasmvnc/kasmvnc.yaml

install -m 644 systemd/runelite@.service /etc/systemd/system/
systemctl daemon-reload

# let the Bolt sandbox run bolt-capture / run-client (read-only)
flatpak override --system --filesystem=/opt/runelite-kiosk:ro com.adamcake.Bolt

echo "kiosk files installed. add an instance with: sudo add-instance <name> <display-number> [--no-login]"
