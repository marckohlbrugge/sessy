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

```bash
npx @smithery/cli auth login
npx @smithery/cli mcp publish "https://api.sessy.do/mcp" \
  -n marckohlbrugge/sessy \
  --config-schema '{"type":"object","properties":{"apiKey":{"type":"string","description":"Sessy API key (Bearer token from app.sessy.do/api_keys)"}},"required":["apiKey"]}'
```

If their scanner can't list tools (auth-gated initialize), fall back to https://smithery.ai/new and paste the URL, or add a static server card later.

## PulseMCP

After the official registry publish, email hello@pulsemcp.com:

> Subject: Please index Sessy SES observability MCP
>
> We published `io.github.marckohlbrugge/sessy` to the official MCP Registry (remote: https://api.sessy.do/mcp). It's read-only Amazon SES observability (bounces/deliveries/stats) — not a send MCP. Homepage: https://sessy.do/blog/amazon-ses-mcp

## Notes

- Initialize without a key returns **401** by design (same as other production remotes in the registry). Clients send the Bearer header on every request.
- Self-hosted instances use the same protocol at `https://<your-host>/mcp`; the registry remote points at hosted for one-click discovery.
