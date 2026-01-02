## Deploying with Kamal

If you'd like to run Sessy on your own server while having the freedom to make changes to its code, we recommend deploying it with [Kamal](https://kamal-deploy.org/).

Kamal makes it easy to set up a bare server, copy the application to it, and manage the configuration settings. This guide assumes you've forked the repository and want to deploy your own version.

> **Just want to run Sessy without code changes?** See [Docker Deployment](docker-deployment.md) for a simpler setup using pre-built images.

### 1. Fork the repository

Start by forking the Sessy repository to your own GitHub account. This lets you make changes and track your customizations.

### 2. Configure your deployment

Edit `config/deploy.yml` to match your setup:

```yaml
# Deploy to these servers (replace with your server's IP or hostname)
servers:
  web:
    - your-server-ip

# Enable SSL with Let's Encrypt (uncomment and configure)
proxy:
  ssl: true
  host: sessy.example.com

# Container registry (default uses Kamal's built-in local registry)
registry:
  server: localhost:5555
```

Key settings to configure:

- **servers/web**: Your server's IP address or hostname (must be accessible via SSH)
- **proxy/ssl**: Set to `true` for automatic Let's Encrypt SSL certificates
- **proxy/host**: Your domain name (required when SSL is enabled)
- **registry**: Defaults to `localhost:5555` which uses Kamal's built-in registry proxy — no external registry needed

### 3. Set up secrets

Create `.kamal/secrets` with your credentials (this file is gitignored):

```sh
# Rails master key (find in config/master.key or generate with bin/rails credentials:edit)
RAILS_MASTER_KEY=your_master_key

# Optional: HTTP Basic Auth for the dashboard
HTTP_AUTH_USERNAME=admin
HTTP_AUTH_PASSWORD=your_secure_password

# Optional: PostgreSQL database (defaults to SQLite if not set)
DATABASE_URL=postgres://user:pass@host/database
```

You can also use 1Password CLI to manage secrets:

```sh
SECRETS=$(kamal secrets fetch --adapter 1password --account YOUR_ACCOUNT --from YOUR_VAULT RAILS_MASTER_KEY)
RAILS_MASTER_KEY=$(kamal secrets extract RAILS_MASTER_KEY $SECRETS)
```

> **Using an external registry?** If you prefer Docker Hub or GitHub Container Registry, update the `registry` section in `config/deploy.yml` and add `KAMAL_REGISTRY_PASSWORD` to your secrets.

### 4. Deploy

For the initial deployment:

```sh
bin/kamal setup
```

For subsequent deployments:

```sh
bin/kamal deploy
```

### Useful commands

Sessy includes helpful Kamal aliases:

```sh
bin/kamal console    # Open Rails console on the server
bin/kamal shell      # Open bash shell on the server
bin/kamal logs       # Tail application logs
bin/kamal dbc        # Open database console
```
