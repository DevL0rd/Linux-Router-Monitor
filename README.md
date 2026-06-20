# Linux-Router-Monitor

A suite of native KDE Plasma 6 widgets that graph live stats from an
**ASUS / Asuswrt-Merlin** router (built for a GT-AXE16000) over SSH, styled to
match Plasma's own System Monitor graphs. CPU, RAM, temperatures, WAN
throughput, WiFi airtime/DFS, per-client signal, AdGuard Home blocking — plus a
control widget to reboot, restart WiFi and toggle AdGuard protection.

This is mostly for myself, but in case my friends use it, here are the
instructions.

## Widgets

| Widget | Shows |
|--------|-------|
| **Router · System**  | CPU (total + per-core), RAM, swap, SoC/radio temperatures, uptime, sessions — plus **Reboot / Restart WiFi / Open web UI** actions |
| **Router · Network** | WAN up/down throughput charts, WAN latency + packet loss, wired port link speeds |
| **Router · WiFi**    | Per-band channel/width/noise/airtime/temperature, **DFS state**, per-band client counts |
| **Router · DNS**     | AdGuard Home **protection toggle**, open-UI button, queries, % blocked, q/s, avg processing time, top blocked domains & clients |
| **Router · Clients** | Device cards (DHCP leases + live WiFi signal & traffic) with pin-to-top, connected status, sort-by-traffic, and per-device actions: SSH, browse files, ping, port scan, copy IP/MAC, rename, reserve IP, disconnect, block internet |
| **Router · Speed Test** | Manual click-to-run internet speed test: download, upload, ping, jitter (Cloudflare) |

Each widget has settings for poll interval, accent colour, and which
sub-sections / charts to show.

## How it works (and why it's light on the router)

Widgets never each open their own SSH connection. A single helper
(`bin/routermon-collect`) does all the work:

* **One connection** — SSH **ControlMaster** keeps a single persistent socket
  that every widget reuses (~10 ms per call).
* **One query per interval** — a `flock`'d JSON cache in `$XDG_RUNTIME_DIR`
  means the first widget to tick each interval refreshes the snapshot; the rest
  just read it. So whether you run one widget or all six, the router sees about
  **one lightweight query per interval**.

The router side is a tiny POSIX-sh script (`router/collect.sh`) that dumps
`nvram` / `wl` / `/proc` values; the desktop side parses it, computes rates,
and merges the AdGuard Home API.

## Requirements

* KDE Plasma 6 (Qt 6), `plasma-sdk` optional (for `plasmoidviewer`)
* `ssh`, `jq`, `curl`, `python3`
* An ASUS router running **Asuswrt-Merlin** with SSH enabled and key-based login
* (Optional) AdGuard Home for the DNS widget

## Installation

```bash
./install.sh
```

Then edit your credentials:

```bash
~/.config/Linux-Router-Monitor/config.json
```

```jsonc
{
  "host": "192.168.50.1",       // router IP
  "user": "admin",              // router SSH user
  "ssh_key": "~/.ssh/id_ed25519",
  "poll_interval": 2,
  "ping_target": "8.8.8.8",
  "adguard": {
    "enabled": true,
    "url": "http://192.168.50.1:3000",
    "username": "admin",
    "password": ""              // your AdGuard Home password
  }
}
```

Re-run `./install.sh` after editing config to push the collector to the router.
Add the widgets via **right-click → Add Widgets → search "Router"**.

> The config file holds your router and AdGuard credentials and is **git-ignored**.

## Uninstallation

```bash
./uninstall.sh
```

Removes the widgets, the `~/.local/bin` links and the runtime cache, and (best
effort) the collector script from the router. Your config and log are kept.

## Layout

```
bin/routermon-collect   desktop collector (SSH ControlMaster + cache + rates + AdGuard)
bin/routermon-ctl       actions: reboot / restart-wifi / protection / disconnect / block / rename / reserve
bin/routermon-speedtest manual download/upload/ping/jitter test (Cloudflare)
router/collect.sh       runs on the router, dumps raw values
shared/lib/             shared QML components (synced into each widget at install)
plasmoids/              the six Plasma 6 applets
config.example.json     template copied to ~/.config/Linux-Router-Monitor/config.json
```

## Notes

* Built and tested against a **GT-AXE16000** on Asuswrt-Merlin. The interface
  map (`eth7=5GHz-1, eth8=5GHz-2, eth9=6GHz, eth10=2.4GHz`) in
  `router/collect.sh` may need adjusting for other models.
* The DNS widget needs the AdGuard Home login set in config, or it shows an
  "unreachable" state.

## License

MIT
