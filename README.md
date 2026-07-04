# Proxmox LXC WatchState

Native WatchState installation notes, scripts, and service definitions for running WatchState directly inside a Proxmox LXC container without Docker.

## Project Goals

- Build a clean native WatchState deployment for Debian-based Proxmox LXC containers.
- Use the upstream Docker image and documentation as a reference, not as the runtime.
- Document every dependency and configuration decision.
- Produce repeatable install, update, validation, backup, and troubleshooting workflows.
- Keep the deployment understandable and maintainable for Proxmox administrators.

## Current Status

This repository is in the project foundation stage. The first milestones are to document the target architecture and reverse-engineer the upstream WatchState container before installing anything.

See [PROJECT.md](PROJECT.md) for the current roadmap.

## Repository Layout

```text
.
├── docs/       Polished installation and operations documentation
├── examples/   Sample configuration files and templates
├── notes/      Project journal and working notes
├── research/   Upstream WatchState analysis
├── scripts/    Installer, updater, and verification scripts
├── systemd/    Native service definitions
└── tests/      Manual and automated validation notes
```

## Guiding Principle

Nothing gets installed until we understand why it is required.
