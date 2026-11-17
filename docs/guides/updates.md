---
title: Updates and channels
order: 7
summary: Stable and beta channels, update checks, notifications, and system updates.
---

# Updates and channels

## Channels

| Channel | What it is |
|---|---|
| `stable` | Tagged releases |
| `beta` | The bleeding edge: a build of every push to `development` |

```bash
bxrig update channel            # show
bxrig update channel beta       # switch
```

Both are also in the control center (Settings → Updates).

## Update BxRig

```bash
bxrig update check              # exit 10 means an update is available
bxrig update apply --yes        # download, verify, replace atomically
```

The release information is signed (Ed25519) and the binary's SHA-256 is checked against it; a bad signature or checksum changes nothing.

## Get told about updates

```bash
bxrig update notifications on     # a daily user timer shows a desktop notification
bxrig update notifications off
```

The notification covers BxRig and pending system packages.

## See what is waiting

```bash
bxrig system updates            # counts, the package list and whether a restart is needed
bxrig system updates --json     # the same as data for scripts and the System panel in the bar
```

It reads only: repository packages from `checkupdates` (the `pacman-contrib` package) and AUR packages from `yay -Qua` or `paru -Qua`. It exits 0 even when updates are waiting, and 4 when `checkupdates` is missing or cannot reach the mirrors.

A restart is called for in two cases, and `needs_reboot` is true for either:

- **Pending.** An update in the list replaces a kernel (`linux`, `linux-lts`, `linux-zen`, `linux-cachyos` and the other flavours, not their `-headers` or `-docs`), `systemd`, `glibc`, `linux-firmware`, a CPU microcode package (`intel-ucode`, `amd-ucode`) or the NVIDIA driver. `reboot_pending` is true.
- **Stale.** The kernel that runs is gone from `/usr/lib/modules`, which means an update already replaced it. `reboot_stale` is true.

`reboot_reasons` says why in words. The last full system upgrade comes from `/var/log/pacman.log`.

## Update the system

```bash
bxrig system update --yes       # snapshot first (snapper or timeshift), then pacman -Syu and yay -Sua
```

## Agent skills

`bxrig skills update --yes` refreshes the skills BxRig installed.
