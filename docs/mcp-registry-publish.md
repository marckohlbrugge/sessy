# Publishing Sessy to the MCP Registry

Canonical listing metadata lives in [`server.json`](../server.json) at the repo root.

## Official registry

```bash
brew install mcp-publisher   # once
mcp-publisher validate
mcp-publisher login github   # browser OAuth as marckohlbrugge
mcp-publisher publish
```

Verify:

```bash
curl -sS "https://registry.modelcontextprotocol.io/v0/servers?search=io.github.marckohlbrugge/sessy" | jq .
```

Expected public page shape: remote Streamable HTTP at `https://api.sessy.do/mcp` with a required `Authorization: Bearer …` header. Homepage: https://sessy.do/blog/amazon-ses-mcp — install docs: https://sessy.do/docs/mcp.

Namespace is `io.github.marckohlbrugge/sessy` (GitHub ownership). A branded `do.sessy/…` namespace needs DNS login later (`mcp-publisher login dns --domain sessy.do`).

After changing listing copy or the endpoint, bump `version` in `server.json` and publish again.

## Smithery

Sessy uses bearer API keys, not OAuth. A bare publish against `/mcp` makes Smithery try RFC 9728 OAuth discovery and fail. After deploy, `https://api.sessy.do/.well-known/mcp/server-card.json` supplies tool metadata without OAuth (do **not** add OAuth well-known — Cursor then ignores configured bearer headers).

```bash
npx @smithery/cli auth login
# Qualified name must use a namespace you own. Branded namespace: sessy

# Config schema: Smithery reserves Authorization for its own OAuth, so the
# Sessy key is collected/forwarded as x-api-key (Sessy accepts that header).
npx @smithery/cli mcp publish "https://api.sessy.do/mcp" \
  -n sessy/mcp \
  --config-schema '{
    "type": "object",
    "properties": {
      "apiKey": {
        "type": "string",
        "title": "API Key",
        "description": "Sessy API key from https://app.sessy.do/api_keys",
        "x-from": { "header": "x-api-key" }
      }
    },
    "required": ["apiKey"]
  }'
```

Use `-n sessy/<slug>` (e.g. `sessy/mcp`). Older personal namespace was `subscriptions`; `marckohlbrugge/sessy` 404s unless that namespace exists.

**Live:** https://smithery.ai/servers/sessy/mcp (gateway: `https://mcp--sessy.run.tools`)

After publish, set listing metadata (display name defaults to the slug `mcp`):

```bash
# API key from ~/.smithery or Library/Application Support/smithery/settings.json
curl -X PATCH "https://api.smithery.ai/servers/sessy%2Fmcp" \
  -H "Authorization: Bearer $SMITHERY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "Sessy",
    "description": "Read-only Amazon SES observability: search events, inspect bounces, pull delivery stats. Point Claude Code, Cursor, or Codex at your Sessy instance — agents cannot send email or change SES settings.",
    "homepage": "https://sessy.do/blog/amazon-ses-mcp",
    "repositoryUrl": "https://github.com/marckohlbrugge/sessy",
    "unlisted": false
  }'
```

Fallback: https://smithery.ai/new with the same URL once the server card is live.

## PulseMCP

After the official registry publish, email hello@pulsemcp.com:

> Subject: Please index Sessy SES observability MCP
>
> We published `io.github.marckohlbrugge/sessy` to the official MCP Registry (remote: https://api.sessy.do/mcp). It's read-only Amazon SES observability (bounces/deliveries/stats) — not a send MCP. Homepage: https://sessy.do/blog/amazon-ses-mcp

## Notes

- Initialize without a key returns **401** by design (same as other production remotes in the registry). Clients send the Bearer header on every request.
- Self-hosted instances use the same protocol at `https://<your-host>/mcp`; the registry remote points at hosted for one-click discovery.
