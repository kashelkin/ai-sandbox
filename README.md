# AI Sandbox

A containerized development environment for [Claude Code](https://claude.ai/claude-code) targeting **.NET projects**. The sandbox comes with .NET 10, NuGet, and Git pre-installed. All outbound traffic is blocked by default — only whitelisted services are accessible.

## How It Works

Two Docker containers run together:

- **sandbox** — the development container with .NET 10, Git, and Claude Code pre-installed
- **firewall** — a companion container that enforces network isolation using `iptables`, `ipset`, and `dnsmasq`

The sandbox container shares the firewall container's network stack, so all traffic is controlled by the firewall. DNS queries are intercepted by `dnsmasq`, which populates an `ipset` with resolved IPs for whitelisted domains. Only those IPs can reach the internet.

### Whitelisted Domains

| Domain | Purpose |
|--------|---------|
| `api.anthropic.com` | Claude API |
| `statsig.anthropic.com` | Feature flags |
| `github.com` | Git operations |
| `registry.npmjs.org` | npm packages |
| `nuget.org` | NuGet packages |
| `visualstudio.com` | Visual Studio services |
| `sentry.io` | Error tracking |

To add or remove a domain, edit `.sandbox/firewall/config/dnsmasq.conf`. Each whitelisted domain has a line in the form:

```
ipset=/example.com/allowed-domains
```

Add a line to allow a domain, or remove a line to block it. Restart the firewall container for changes to take effect:

```bash
docker compose restart firewall
```

## Prerequisites

- Docker and Docker Compose
- A valid Claude Code installation on the host (credentials at `~/.claude.json`)

## Usage

### Linux / macOS

```bash
cd .sandbox
docker compose run sandbox bash
```

### Windows

Run PowerShell as Administrator:

```powershell
cd .sandbox
.\setup.ps1
docker compose run sandbox bash
```

The `setup.ps1` script creates required Claude Code configuration directories and placeholder files on the host. Only needed on first run.

`docker compose run` automatically starts the firewall container as a dependency before launching the sandbox session.

Your project files are mounted at `/src`. Claude Code credentials and settings are mounted from the host.

Place your .NET project code in the `src/` directory at the root of this repository — it will be available at `/src` inside the container.

## Project Structure

```
.
├── .sandbox/
│   ├── Dockerfile              # Development container image
│   ├── docker-compose.yml      # Container orchestration
│   ├── setup.ps1               # Windows setup script
│   ├── .env                    # Container user configuration
│   └── firewall/
│       ├── Dockerfile          # Firewall container image
│       ├── config/
│       │   └── dnsmasq.conf    # DNS resolver and ipset configuration
│       └── scripts/
│           ├── init.sh         # iptables rules and firewall validation
│           └── start.sh        # Firewall startup script
└── src/                        # Your project code (mounted into sandbox)
```

## Security Notes

- The sandbox runs as the non-root `vscode` user
- `NET_ADMIN` and `NET_RAW` capabilities are only granted to the firewall container
- Claude Code credentials and settings are mounted from the host
- On startup, the firewall validates isolation by confirming that blocked domains (e.g. `example.com`) are unreachable and that whitelisted domains (e.g. `github.com`) are accessible
- The sandbox container only starts after the firewall passes its health check
