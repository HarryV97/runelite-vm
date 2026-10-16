# RuneLite VM: an always-on RuneLite in your browser

Run [RuneLite](https://runelite.net) (Old School RuneScape) 24/7 on a home server or VM,
and open it from any device on your network in a browser window. It looks and behaves like
the RuneLite client itself: no Linux desktop, no taskbar, and the game resizes with the
window. Close the window on your PC, open the link on your laptop, and you're exactly where
you left off.

- **Jagex accounts work.** Login goes through the [Bolt launcher](https://codeberg.org/Adamcake/Bolt).
- **Several accounts:** each account gets its own isolated *instance*, with its own link and
  saved login, and they can run at the same time.
- **Survives reboots and crashes:** the client comes back by itself, still logged in.
- **Light:** no GPU needed. Roughly 0.7 CPU core and 700 MB RAM per client in game.

Built for light play: idling, GE trading, bank-standing tasks. The game still logs you out
after 5 minutes idle and after 6 hours. Just click *Play Now* again. Don't add anything that
fakes input to stop that: Jagex treats it as macroing.

> Not affiliated with Jagex, RuneLite or Bolt. Bolt is an unofficial, open-source launcher.
> Use at your own risk.

---

## What you need

- A machine or VM running **Debian 13 (trixie)**, **x86_64**, *without* a desktop
  environment. A Proxmox VM is perfect.
- **2 CPU cores, 4 GB RAM, 32 GB disk** for one or two accounts (add ~1.5 GB RAM per extra account).
- A Jagex account, and devices on the same network to play from.

## 1. Create the VM (Proxmox)

*Using something else (another hypervisor, an old PC)? Just install Debian 13 the same way.*

1. Download the **Debian 13 netinst ISO** (debian.org) into your Proxmox ISO storage.
2. **Create VM:** OS = that ISO · System: machine `q35`, **Qemu Agent ✔** · Disk 32 GB
   (SSD emulation + discard if on SSD) · CPU **2 cores, type `host`** · Memory **4096** ·
   Network default (`virtio`, `vmbr0`) · Options: **Start at boot ✔**.
3. Start it, open the **Console**, choose **Install**:
   - hostname e.g. `runelite`; leave the **root password blank** (your user gets `sudo`)
   - partitioning: guided, entire disk, **all files in one partition**
   - **Software selection: untick "Debian desktop environment" and "GNOME"**, tick only
     **SSH server** and **standard system utilities**
   - install GRUB to the primary drive (`/dev/sda`)
4. After it reboots, log in and find its IP with `ip a`. Then install the guest agent:
   ```bash
   sudo apt install -y qemu-guest-agent
   ```
   Tip: give the VM a fixed IP (a DHCP reservation in your router is easiest), so your
   bookmarks keep working.

## 2. Install

SSH into the VM (`ssh <you>@<vm-ip>`), then:

```bash
sudo apt install -y git
git clone https://github.com/HarryV97/runelite-vm.git runelite-vm
cd runelite-vm
sudo ./setup.sh
```

<details>
<summary>Repo is private? How to clone it</summary>

GitHub doesn't accept account passwords for `git clone`. Use one of these:

- **Access token** (you must be a collaborator): GitHub → Settings → Developer settings →
  Personal access tokens → *Fine-grained* → only this repo, **Contents: Read-only**. Run the
  `git clone` above. When it asks, use your GitHub username and **paste the token as the
  password**. Don't put the token in the URL.
- **Deploy key** (no GitHub account needed): on the VM run
  `ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519` and `cat ~/.ssh/id_ed25519.pub`. The repo
  owner adds that line under repo Settings → Deploy keys (read-only). Then
  `git clone git@github.com:HarryV97/runelite-vm.git runelite-vm`.

</details>

`setup.sh` installs everything: KasmVNC (the browser streaming server), Openbox, Flatpak,
the Bolt launcher, and the kiosk scripts. It downloads about 1.5 GB and takes a few minutes.
It's safe to run again.

## 3. Create your first instance

```bash
sudo add-instance main 1
```

- `main` is a name you choose (lowercase letters/digits). `1` is the display number, and
  the instance's web address uses port **8443 + that number** → `https://<vm-ip>:8444`.
- It asks you to pick a **web password**. The web username is **`runelite`**. This only
  protects the stream page. It's *not* your Jagex password.
- Only you on a trusted home network? `sudo add-instance main 1 --no-login` skips the web
  password. Then anyone who can reach the VM can open it and play your logged-in character.

## 4. First login

1. Open **`https://<vm-ip>:8444`** in Chrome/Edge/Firefox. The certificate is self-signed,
   so accept the warning once (*Advanced → Proceed*).
2. Enter the web login (unless you used `--no-login`).
3. **Bolt** is already showing. Accept its notice → log in to your Jagex account → pick
   your **Character** → **Play**.
4. Bolt closes and RuneLite starts. The first start takes ~30 s while it downloads.

**Character list empty?** Bolt sometimes hasn't loaded your characters right after you log
in. Restart Bolt and they appear:
```bash
sudo pkill -u rl-main -x bolt
```
Then press **Ctrl+Alt+B** (or wait a few seconds: Bolt reopens by itself until you've played once).

That's it. From now on, the link opens straight into your running client.

---

## Everyday use

| You want to… | Do this |
|---|---|
| Play | Open `https://<vm-ip>:8444`. Click *Play Now* if the game logged you out |
| Stop playing | Just close the window. The client keeps running on the server |
| Play from another device | Open the same link. Several windows can be open at once; they all show the same client |
| Open Bolt (switch login) | **Ctrl+Alt+B** inside the instance |
| Another character on the same Jagex account | Ctrl+Alt+B → pick it under **Character** → **Play** |
| Another Jagex account | Ctrl+Alt+B → click the account name (top right) → add/log in → pick a character → **Play** |
| Restart / update RuneLite | Click into the game and press **Alt+F4**. It comes back in ~15 s and updates as it starts. Or: `sudo pkill -u rl-main -x java` |
| Restart the whole instance | `sudo systemctl restart runelite@main` |

Pressing **Play** in Bolt never opens a second game. It swaps the running client to that
character, and that character is the one that comes back after a reboot.

**Tip: make it feel like an app.** In Edge: ⋯ → Apps → *Install this site as an app*. In
Chrome: ⋮ → Cast, save and share → *Install page as app*. You get a standalone window with
its own taskbar icon.

### More accounts at the same time

```bash
sudo add-instance alt 2              # → https://<vm-ip>:8445
sudo add-instance third 3 --no-login # → https://<vm-ip>:8446
```

Each instance is a separate Linux user (`rl-<name>`), so logins, RuneLite settings and
plugins never mix. Check Jagex's current rules on playing several accounts at once.

### Change or remove things

```bash
sudo add-instance main 1 --no-login   # turn the web login off for an instance (restarts it)
sudo add-instance main 1 --login      # turn it back on (asks for a new password, restarts it)
sudo -u rl-main -H kasmvncpasswd -u runelite -w   # change an instance's web password
sudo remove-instance alt              # delete an instance and ALL its data (asks to confirm)
```

### Updating

- **RuneLite** updates itself every time it starts.
- **Bolt:** `sudo flatpak update -y`
- **These scripts:** `cd runelite-vm && git pull && sudo ./setup.sh`, then restart instances
  (`sudo systemctl restart runelite@main`).

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Page won't load | `systemctl status runelite@main`. If it's not running: `sudo systemctl restart runelite@main` |
| Blue box *"KasmVNC encountered an error: Failed to decode frame at index 0"* | Cosmetic. It happens when a second window joins or windows are different sizes. The game keeps running; dismiss it or reload the page |
| Black screen / client gone | Wait ~15 s (it restarts itself). Still nothing: `sudo tail -f /home/rl-main/.vnc/supervisor.log` |
| Session expired / invalid in RuneLite | Ctrl+Alt+B → log in again → **Play** |
| Text blurry on a high-DPI laptop | In the KasmVNC side panel (small arrow on the left edge), look for the scaling / device-pixel-ratio options |
| Start completely fresh (forget all Jagex logins) | `sudo systemctl stop runelite@main`, then `sudo rm -f /home/rl-main/.var/app/com.adamcake.Bolt/data/bolt-launcher/creds /home/rl-main/.var/app/com.adamcake.Bolt/data/kiosk/session`, then `sudo systemctl start runelite@main` |

Logs: `/home/rl-<name>/.vnc/supervisor.log` (the restart loop), `/home/rl-<name>/.vnc/*.log`
(KasmVNC), `/home/rl-<name>/.var/app/com.adamcake.Bolt/data/bolt-launcher/.runelite/logs/client.log`
(RuneLite). *"Error initializing sound engine"* in the RuneLite log is normal: there's no audio.

## Security notes

- Keep this on your **home network**. Don't port-forward it to the internet. For access
  from outside, use a VPN such as Tailscale or WireGuard.
- Your Jagex password is only ever typed into Bolt, never stored by these scripts. Bolt
  keeps its own saved login (`…/bolt-launcher/creds`), and the kiosk saves the current game
  session (`…/data/kiosk/session`, mode 600). Both are as sensitive as a password. They
  stay on the VM, and instance home folders are private (`700`).
- `--no-login` instances can be opened (and played) by anything that can reach the VM.

## How it works

See **[docs/how-it-works.md](docs/how-it-works.md)**. Short version: KasmVNC streams a bare
X display to the browser. Openbox keeps every window borderless and maximized. A small
supervisor keeps RuneLite running. Bolt's *custom launch command* is pointed at a script
that saves the Jagex session when you press Play, so the supervisor can start RuneLite
with it, including after reboots.

## Files

```
setup.sh              one-shot installer (packages, KasmVNC, Bolt, kiosk files)
install.sh            (re)installs the kiosk files only; setup.sh calls it
add-instance          create/update an instance      → /usr/local/sbin
remove-instance       delete an instance             → /usr/local/sbin
kiosk/                                               → /opt/runelite-kiosk
  xstartup              X session: Openbox + supervisor
  supervisor            keeps RuneLite running; opens Bolt when not logged in
  bolt-capture          Bolt launch command: saves the session instead of launching
  run-client            replays the saved launch inside Bolt's Flatpak sandbox
  openbox-rc.xml        no borders, maximized, Ctrl+Alt+B
  kasmvnc.yaml          shared KasmVNC settings      → /etc/kasmvnc/kasmvnc.yaml
  bolt-launcher.json    starting Bolt settings for new instances
  runelite-settings.properties   starting RuneLite settings (GPU off, FPS cap)
systemd/runelite@.service   one service per instance
docs/how-it-works.md
```

## Uninstall

```bash
sudo remove-instance main            # for each instance
sudo rm -rf /opt/runelite-kiosk /etc/runelite-kiosk /etc/systemd/system/runelite@.service /usr/local/sbin/add-instance /usr/local/sbin/remove-instance
sudo mv /etc/kasmvnc/kasmvnc.yaml.orig /etc/kasmvnc/kasmvnc.yaml
sudo flatpak uninstall -y com.adamcake.Bolt && sudo apt purge -y kasmvncserver
```
Or simply delete the VM.
