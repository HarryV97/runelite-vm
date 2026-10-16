# How it works

```
VM (Debian 13, no desktop)
├── instance "main"   Linux user rl-main   display :1   https://<vm-ip>:8444
│     KasmVNC ─ Openbox ─ supervisor ─ RuneLite (saved Jagex session)
├── instance "alt"    Linux user rl-alt    display :2   https://<vm-ip>:8445
│     KasmVNC ─ Openbox ─ supervisor ─ RuneLite
└── …  (port = 8443 + display number)
```

## Why these pieces

| Need | Choice | Why |
|---|---|---|
| Stream to a browser, resize with the window | **KasmVNC** | Web client built in, "remote resize", session survives closing the tab |
| Look like the client, not a desktop | **Openbox**, no desktop environment | Keeps windows borderless and maximized; one hotkey |
| Jagex account login on Linux | **Bolt** (Flatpak `com.adamcake.Bolt`) | The official Jagex Launcher is Windows/Mac only |
| Several accounts | **One Linux user per instance** | Full isolation; ~0.7 GB RAM each instead of a VM each |
| Host | A plain VM | Flatpak (Bolt) works best outside Docker |

Ruled out: linuxserver/webtop and Kasm Workspaces (show a full desktop; Flatpak inside
Docker is fiddly), Sunshine/Moonlight and Parsec (need an app on every device), plain
noVNC/Guacamole (no remote resize).

## Inside an instance

1. **`runelite@<name>.service`** runs as `rl-<name>`. It starts KasmVNC on display `:N`
   (port `8443+N`), with settings from `/etc/runelite-kiosk/<name>.env`. The user has
   *lingering* enabled, so it gets `/run/user/<uid>` and a session D-Bus without anyone
   logging in. Flatpak needs both.
2. **`xstartup`** starts **Openbox** with `openbox-rc.xml` and the **supervisor**. There's
   no panel, menu or wallpaper.
3. **Openbox rules:** normal windows (RuneLite, Bolt) have no decorations and stay
   maximized, so they fill the display and refit whenever it's resized. Dialogs keep their
   own size. **Ctrl+Alt+B** runs Bolt.
4. **`supervisor`** loops every few seconds:
   - no saved session → open Bolt (first login)
   - saved session, no client running → start RuneLite (also after crashes and reboots)
   - session file changed (Play pressed in Bolt) → stop RuneLite and start it as the new character

### Resizing

Resize the browser window → the KasmVNC web client asks the server to resize the X display
→ Openbox re-maximizes RuneLite → RuneLite's resizable mode relays out the game.

## The login trick (Bolt → supervisor)

Bolt normally starts RuneLite itself:

```
java -Duser.home=<bolt data dir> -jar runelite.jar -J-Duser.home=<bolt data dir>
```

with the Jagex login passed in the environment variables `JX_SESSION_ID`,
`JX_CHARACTER_ID` and `JX_DISPLAY_NAME`. Bolt has a **RuneLite launch command** setting,
where `%command%` stands for that java command and the first word must be an absolute
path. Every instance's Bolt is pre-configured (`kiosk/bolt-launcher.json`) with:

```
/opt/runelite-kiosk/bolt-capture %command%
```

So pressing **Play** runs `bolt-capture` inside Bolt's Flatpak sandbox. It doesn't start
the game. It writes the `JX_*` values plus the java command to
`~/.var/app/com.adamcake.Bolt/data/kiosk/session` (mode 600) and exits. Bolt is set to close
after launching.

The supervisor notices the new file and runs:

```
flatpak run --command=/opt/runelite-kiosk/run-client com.adamcake.Bolt
```

`run-client` loads the session file and replays the command inside the same sandbox,
using Bolt's bundled Java. The sandbox is allowed to read `/opt/runelite-kiosk` through
`flatpak override --filesystem=/opt/runelite-kiosk:ro`.

Results:
- Pressing Play = log in, or switch account/character.
- RuneLite always belongs to the supervisor, so crashes and reboots bring it back logged
  in, without opening Bolt.

(Worked out from the Bolt 0.24 source: `src/browser/window_launcher_posix.cxx` and
`app/src/lib/Util/Config.ts`.)

## Starting RuneLite settings

RuneLite imports `~/.runelite/settings.properties` into a `default` profile the first time
it starts with no profiles. `add-instance` places `kiosk/runelite-settings.properties`
there:

- **GPU plugin off.** RuneLite enables it by default, but with no GPU it renders in software
  (llvmpipe). That cut CPU from ~36% to ~7.5% at the login screen.
- **FPS Control:** 25 fps (10 when unfocused). OSRS ticks every 0.6 s, and the stream is
  capped at 30 fps anyway.
- **Custom window chrome off**, because Openbox already removes borders.

## KasmVNC settings (`kiosk/kasmvnc.yaml`)

- `allow_resize: true`: the browser window size drives the display size
- `websocket_port: auto`: 8443 + display number
- self-signed `ssl-cert` snakeoil certificate (instance users are in the `ssl-cert` group)
- `max_frame_rate: 30`, `session_type: shared` (several viewers at once)
- `command_line.prompt: false`, so it never asks interactive questions under systemd
- Web login: KasmVNC refuses to start without a user in `~/.kasmpasswd`, so `--no-login`
  instances get one with a random password, and the service adds `-DisableBasicAuth 1`
  (via `KASM_EXTRA_ARGS` in the instance's `.env`).

## Files on the VM

| Path | What |
|---|---|
| `/opt/runelite-kiosk/` | shared scripts and templates (from `kiosk/`) |
| `/etc/kasmvnc/kasmvnc.yaml` | shared KasmVNC settings (the original is saved as `.orig`) |
| `/etc/systemd/system/runelite@.service` | instance service |
| `/etc/runelite-kiosk/<name>.env` | per instance: display, runtime dir, D-Bus, web login |
| `/usr/local/sbin/add-instance`, `remove-instance` | instance management |
| `~rl-<name>/.kasmpasswd` | KasmVNC web user |
| `~rl-<name>/.vnc/` | KasmVNC logs, `supervisor.log` |
| `~rl-<name>/.var/app/com.adamcake.Bolt/config/bolt-launcher/launcher.json` | Bolt settings |
| `~rl-<name>/.var/app/com.adamcake.Bolt/data/bolt-launcher/creds` | Bolt's saved Jagex logins |
| `~rl-<name>/.var/app/com.adamcake.Bolt/data/bolt-launcher/.runelite/` | RuneLite settings, plugins, logs |
| `~rl-<name>/.var/app/com.adamcake.Bolt/data/kiosk/session` | saved game session |

## Measured (i7-7700T host, 2 vCPU / 4 GB VM)

| State | CPU | RAM |
|---|---|---|
| RuneLite at the login screen, GPU plugin on (default) | ~36% of a core | ~540 MB |
| …GPU plugin off + 25 fps cap | ~7.5% | ~420 MB |
| In game, 1718×1270 window | ~67% | ~710 MB |
