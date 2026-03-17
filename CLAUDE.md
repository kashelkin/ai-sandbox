# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI Sandbox is a containerized development environment for Claude Code targeting .NET projects. It uses a two-container architecture to provide a secure, isolated workspace with strict network controls.

## Architecture

### Two-Container Design

**Sandbox container** (`.sandbox/Dockerfile`):
- Based on `mcr.microsoft.com/devcontainers/dotnet:10.0`
- Runs as non-root `vscode` user (no sudo)
- `NET_ADMIN` and `NET_RAW` capabilities dropped
- Mounts project code at `/src`, Claude credentials from host, and shared caches

**Firewall container** (`.sandbox/firewall/`):
- Based on Ubuntu 22.04 with `iptables`, `ipset`, `dnsmasq`
- Has `NET_ADMIN` and `NET_RAW` for traffic control
- The sandbox shares the firewall's network stack (`network_mode: service:firewall`)
- Sandbox only starts after firewall passes its health check (`/tmp/firewall-ready`)

### Network Isolation Flow

DNS queries from the sandbox go to a local `dnsmasq` instance (127.0.0.1:53), which resolves domains and dynamically adds their IPs to an `allowed-domains` ipset. `iptables` OUTPUT rules only permit traffic to IPs in that ipset — everything else is dropped.

On startup, `init.sh` validates isolation by confirming `example.com` is blocked and `github.com` is reachable.

### Whitelisted Domains

Configured in `.sandbox/firewall/config/dnsmasq.conf` via `ipset=` directives:
- `api.anthropic.com`, `statsig.anthropic.com` — Claude API
- `github.com` — Git operations
- `registry.npmjs.org` — npm packages
- `nuget.org`, `visualstudio.com` — .NET packages
- `sentry.io` — Error telemetry

## Common Commands

**Start the sandbox** (Linux/macOS):
```bash
cd .sandbox
docker compose up -d
docker compose exec sandbox bash
```

**Windows** (one-time setup then run):
```powershell
cd .sandbox
.\setup.ps1
docker compose up -d
docker compose exec sandbox bash
```

**Manage the firewall**:
```bash
docker compose restart firewall   # Apply dnsmasq.conf changes
docker compose logs firewall      # View firewall logs
docker compose down               # Stop all containers
```

## Adding Whitelisted Domains

1. Add a line to `.sandbox/firewall/config/dnsmasq.conf`:
   ```
   ipset=/newdomain.com/allowed-domains
   ```
2. Run `docker compose restart firewall` — no sandbox restart needed.

## Key Configuration Files

| File | Purpose |
|------|---------|
| `.sandbox/docker-compose.yml` | Defines services, volumes, networking, health checks |
| `.sandbox/Dockerfile` | Sandbox image: .NET 10, git-delta, Claude Code CLI |
| `.sandbox/.env` | Container username (default: `vscode`) |
| `.sandbox/firewall/config/dnsmasq.conf` | Domain whitelist |
| `.sandbox/firewall/scripts/init.sh` | Core firewall logic (iptables rules + validation) |
| `.sandbox/firewall/scripts/start.sh` | Firewall entrypoint |

## Development Rules

- **After any change to this repo**, update `README.md` to reflect the change.
- **When adding a new folder or file mount** to `docker-compose.yml`, also add creation of that folder or file to `setup.ps1` so Windows users have it created automatically before first run.
- **When adding a new parameter** to `.sandbox/.env`, add a comment above it explaining its purpose and any constraints (e.g. valid values, which scripts depend on it).

## Line Ending Requirement

Firewall scripts and configs must use Unix line endings (LF). A `.gitattributes` file in `.sandbox/firewall/` enforces this. If firewall scripts fail on startup, check for CRLF line endings.
