# LXC Baseline

## Container

- CT ID: 103
- Hostname: watchstate
- OS: Debian GNU/Linux 13 trixie
- Virtualization: LXC
- CPU: 2 cores
- Memory: 4 GB
- Swap: 4 GB
- Root disk: 16 GB
- Network: DHCP on eth0 via vmbr0
- Media bind mounts: none

## Creation Note

Proxmox reported a Debian 13 systemd warning during creation:

```text
WARN: Systemd 257 detected. You may need to enable nesting.
```

Decision: enable nesting for this Debian 13 container.

```bash
pct set 103 -features nesting=1
```

This is for Debian 13 systemd compatibility. It does not mean Docker will be used.

## Validation

Validated output showed:

- Static hostname: watchstate
- Operating system: Debian GNU/Linux 13 trixie
- Virtualization: lxc
- Interface eth0 is UP
- DHCP address: 192.168.0.76/24
- Default route: 192.168.0.1 via eth0

## Next Step

Run package updates, reboot, then take a clean Proxmox snapshot before installing WatchState prerequisites.
