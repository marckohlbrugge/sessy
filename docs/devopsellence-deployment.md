## Deploying with devopsellence

This guide covers deploying Sessy to a VM with [devopsellence](https://www.devopsellence.com/).

devopsellence keeps Sessy as an ordinary Dockerized Rails app: it builds the existing Dockerfile,
persists `/rails/storage`, configures HTTPS ingress, and reconciles the running container on your VM.

### 1. Install devopsellence

Install the CLI on your workstation:

```bash
curl -fsSL https://www.devopsellence.com/lfg.sh | bash
```

Make sure your VM is reachable over SSH and has Docker installed. You can also create a provider-backed
solo node with devopsellence if you have configured a supported provider.

### 2. Initialize solo mode

From your local Sessy checkout:

```bash
devopsellence init --mode solo
```

Create or replace `devopsellence.yml` with the following configuration. Replace `sessy.example.com` and
`ops@example.com` with your values.

```yaml
schema_version: 1
organization: solo
project: sessy
default_environment: production

build:
  context: .
  dockerfile: Dockerfile
  platforms:
    - linux/amd64

services:
  web:
    ports:
      - name: http
        port: 80
    healthcheck:
      path: /up
      port: 80
    volumes:
      - source: sessy_storage
        target: /rails/storage
    env:
      RAILS_ENV: production
      SOLID_QUEUE_IN_PUMA: "true"
    secret_refs:
      - name: SECRET_KEY_BASE
        secret: SECRET_KEY_BASE
      - name: HTTP_AUTH_USERNAME
        secret: HTTP_AUTH_USERNAME
      - name: HTTP_AUTH_PASSWORD
        secret: HTTP_AUTH_PASSWORD

tasks:
  release:
    service: web
    command:
      - ./bin/rails
      - db:prepare

ingress:
  hosts:
    - sessy.example.com
  rules:
    - match:
        host: sessy.example.com
        path_prefix: /
      target:
        service: web
        port: http
  tls:
    mode: auto
    email: ops@example.com
  redirect_http: true
```

Notes:

- Sessy's Dockerfile exposes port `80`, so the service and health check use port `80`.
- `/rails/storage` persists SQLite, Solid Queue, Solid Cache, Solid Cable, and local storage data.
- `SOLID_QUEUE_IN_PUMA=true` runs background jobs inside the web process for a simple single-VM deploy.
- devopsellence handles HTTPS at ingress, so do not set `DISABLE_SSL=true` for this production shape.

### 3. Configure required secrets

Set a Rails secret and HTTP Basic Auth credentials for the dashboard. Webhook endpoints remain accessible
without auth so AWS SNS can deliver SES events.

```bash
openssl rand -hex 64 | devopsellence secret set SECRET_KEY_BASE --service web --stdin
printf '%s' 'admin' | devopsellence secret set HTTP_AUTH_USERNAME --service web --stdin
printf '%s' '<strong-password>' | devopsellence secret set HTTP_AUTH_PASSWORD --service web --stdin
```

For production, you can reference secrets from 1Password instead of storing plaintext in local solo state:

```bash
devopsellence secret set SECRET_KEY_BASE --service web --store 1password --op-ref "op://deploy/sessy/secret-key-base"
devopsellence secret set HTTP_AUTH_USERNAME --service web --store 1password --op-ref "op://deploy/sessy/http-auth-username"
devopsellence secret set HTTP_AUTH_PASSWORD --service web --store 1password --op-ref "op://deploy/sessy/http-auth-password"
```

### 4. Deploy

Attach your VM as a solo node, run a dry-run, then deploy:

```bash
devopsellence node attach prod-1
devopsellence doctor
devopsellence deploy --dry-run
devopsellence deploy
devopsellence status
```

The same `devopsellence deploy` command can be used for the initial deployment and future updates.

### 5. Connect Amazon SES

After Sessy is online:

1. Open `https://sessy.example.com`.
2. Create a source for your SES configuration set.
3. Copy the source webhook URL, which looks like `https://sessy.example.com/webhooks/<source-token>`.
4. In Amazon SES, route configuration set events to an SNS topic with an HTTPS subscription to that
   webhook URL.
5. Make sure your app sends mail with the matching `X-SES-CONFIGURATION-SET` header.

For the full AWS side of the setup, see [AWS SES setup for Sessy](aws-ses-setup.md).
