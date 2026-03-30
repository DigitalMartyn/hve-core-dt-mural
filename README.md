# Mural MCP Integration for HVE Core Design Thinking

Export Design Thinking artifacts from [microsoft/hve-core](https://github.com/microsoft/hve-core) to collaborative [Mural](https://www.mural.co/) boards using GitHub Copilot and the Model Context Protocol (MCP).

This repository contains the Mural MCP integration branch for the HVE Core Design Thinking collection. It adds a Copilot prompt, PowerShell MCP server scripts, and Pester tests that let you push DT coaching artifacts onto Mural boards directly from VS Code.

## What's Included

| Path | Purpose |
|------|---------|
| `.github/prompts/design-thinking/dt-mural-export.prompt.md` | Copilot prompt for exporting DT artifacts to Mural |
| `.github/agents/design-thinking/dt-coach.agent.md` | DT Coach agent updated with Mural export awareness |
| `scripts/mcp/Setup-MuralMcp.ps1` | Clone, build, and authenticate the upstream Mural MCP server |
| `scripts/mcp/Start-MuralMcp.ps1` | Launch the Mural MCP server for VS Code |
| `scripts/mcp/Modules/MuralMcp.psm1` | Shared PowerShell module for Mural MCP operations |
| `scripts/tests/mcp/MuralMcp.Tests.ps1` | Pester tests for the MCP module |
| `docs/design-thinking/mural-export.md` | Full documentation |
| `docs/getting-started/mcp-configuration.md` | MCP server configuration guide |

## Prerequisites

- [VS Code](https://code.visualstudio.com/) with [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)
- [PowerShell 7+](https://github.com/PowerShell/PowerShell) (`pwsh`)
- [Node.js](https://nodejs.org/) (for `npx`)
- A [Mural](https://www.mural.co/) account with API access
- A Mural OAuth app (Client ID and Client Secret)

## Setup

### 1. Clone this repository

```bash
git clone https://github.com/DigitalMartyn/hve-core-dt-mural.git
cd hve-core-dt-mural
```

### 2. Configure Mural credentials

```bash
cp .mural-credentials.example .mural-credentials
```

Edit `.mural-credentials` and add your Mural OAuth app values:

```text
MURAL_CLIENT_ID=your_client_id_here
MURAL_CLIENT_SECRET=your_client_secret_here
```

### 3. Run the setup script

```bash
npm run mcp:setup:mural
```

This clones the upstream `mural-mcp` server, builds it, and runs the OAuth flow in your browser.

### 4. Add the MCP server to VS Code

Create or update `.vscode/mcp.json` in your workspace root:

```json
{
  "servers": {
    "mural": {
      "type": "stdio",
      "command": "pwsh",
      "args": ["-File", "./scripts/mcp/Start-MuralMcp.ps1"]
    }
  }
}
```

### 5. Restart VS Code

The Mural MCP server should appear under **MCP Servers** in the VS Code sidebar.

## Usage

Open Copilot Chat and run the export prompt:

```text
/dt-mural-export project-slug=factory-floor-maintenance
```

With optional arguments:

```text
/dt-mural-export project-slug=customer-support-ai board-title="Stakeholder Map" method=1
```

The prompt reads DT artifacts from `.copilot-tracking/dt/{project-slug}/`, verifies the Mural MCP server is available, and creates sections, labels, and sticky notes on a Mural board.

## Supported DT Methods

| Method | What Gets Exported |
|--------|--------------------|
| 1 - Scope Conversations | Stakeholder maps, constraints, open questions |
| 3 - Synthesis | Themes, evidence clusters, how-might-we prompts |
| 4 - Brainstorming | Idea clusters, convergence candidates |
| 5 - User Concepts | Concepts, evaluation notes, stakeholder reactions |
| 6 - Low-Fidelity Prototypes | Prototype plans, build decisions, testing hypotheses |

## Running Tests

```bash
pwsh -Command "Invoke-Pester ./scripts/tests/mcp/MuralMcp.Tests.ps1 -Output Detailed"
```

## Troubleshooting

**Mural tools unavailable in Copilot Chat** — Check that `.vscode/mcp.json` includes the `mural` server entry and restart VS Code.

**Authentication fails** — Re-run `npm run mcp:setup:mural`. The setup script detects expired tokens and restarts OAuth.

**No DT artifacts found** — Confirm `.copilot-tracking/dt/{project-slug}/coaching-state.md` exists. Run DT coaching first to generate artifacts.

## Contributing

Contributions welcome. This integration is designed to merge upstream into [microsoft/hve-core](https://github.com/microsoft/hve-core) as part of the Design Thinking collection.

1. Fork this repo
2. Create a feature branch
3. Make your changes
4. Open a pull request

## Related

- [microsoft/hve-core](https://github.com/microsoft/hve-core) — Parent repository
- [Mural](https://www.mural.co/) — Collaborative whiteboarding platform
- [Model Context Protocol](https://modelcontextprotocol.io/) — MCP specification


## License

This project is licensed under the [MIT License](./LICENSE).
