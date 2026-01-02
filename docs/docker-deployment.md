## Deploying with Docker

We provide pre-built Docker images that can be used to run Sessy on your own server.

If you don't need to change the source code, and just want the out-of-the-box Sessy experience, this can be a great way to get started.

You'll find the latest version of Sessy's Docker image at `ghcr.io/marckohlbrugge/sessy:main`.
To run it you'll need three things: a machine that runs Docker; a mounted volume (so that your database is stored somewhere that is kept around between restarts); and some environment variables for configuration.

### Mounting a storage volume

The standard Sessy setup keeps all of its storage inside the path `/rails/storage`.
By default Docker containers don't persist storage between runs, so you'll want to mount a persistent volume into that location.

The simplest way to do this is with the `--volume` flag with `docker run`. For example:

```sh
docker run --volume sessy:/rails/storage ghcr.io/marckohlbrugge/sessy:main
```

That will create a named volume (called `sessy`) and mount it into the correct path.
Docker will manage where that volume is actually stored on your server.

You can also specify the data location yourself, mount a network drive, and more.
Check the Docker documentation to find out more about what's available.

### Configuring with environment variables

To configure your Sessy installation, you can use environment variables.
Many of these are optional, but at a minimum you'll want to configure your secret key.

#### Secret Key Base

Various features inside Sessy rely on cryptography to work.
To set this up, you need to provide a secret value that will be used as the basis of those secrets.
This value can be anything, but it should be unguessable, and specific to your instance.

You can generate a random key with:

```sh
openssl rand -hex 64
```

Once you have one, set it in the `SECRET_KEY_BASE` environment variable:

```sh
docker run --environment SECRET_KEY_BASE=abcdefabcdef ...
```

#### SSL

By default, Sessy assumes it's running behind an SSL-terminating proxy and enforces HTTPS.

If you're running Sessy behind a reverse proxy that handles SSL (like Cloudflare, nginx, or Caddy), you don't need to change anything.

If you aren't using SSL at all (for example, if you want to run it locally on your laptop) then you should specify `DISABLE_SSL=true`:

```sh
docker run --publish 80:80 --environment DISABLE_SSL=true ...
```

#### HTTP Basic Auth

Sessy can be protected with HTTP Basic Authentication. This is recommended for production deployments to prevent unauthorized access to your email data.

Set the `HTTP_AUTH_USERNAME` and `HTTP_AUTH_PASSWORD` environment variables:

```sh
docker run \
  --environment HTTP_AUTH_USERNAME=admin \
  --environment HTTP_AUTH_PASSWORD=your-secure-password \
  ...
```

When both variables are set, Sessy will require authentication to access the dashboard. Webhook endpoints remain accessible without authentication so AWS SES can deliver events.

If HTTP Basic Auth is not configured, Sessy will display a security warning banner. To disable this warning (for example, if you're using a different authentication method), set:

```sh
docker run --environment DISABLE_AUTH_WARNING=true ...
```

#### Database

By default, Sessy uses SQLite and stores its database in the mounted storage volume. This is the simplest setup and works great for most use cases.

If you'd prefer to use PostgreSQL, set the `DATABASE_URL` environment variable:

```sh
docker run --environment DATABASE_URL=postgres://user:pass@host/sessy ...
```

Sessy will automatically detect PostgreSQL from the URL and configure itself accordingly.

## Example

Here's an example of a `docker-compose.yml` that you could use to run Sessy via `docker compose up`:

```yaml
services:
  web:
    image: ghcr.io/marckohlbrugge/sessy:main
    restart: unless-stopped
    ports:
      - "80:80"
    environment:
      - SECRET_KEY_BASE=your-secret-key-here
      - HTTP_AUTH_USERNAME=admin
      - HTTP_AUTH_PASSWORD=your-secure-password
      - DISABLE_SSL=true
    volumes:
      - sessy:/rails/storage

volumes:
  sessy:
```

For production with SSL handled by a reverse proxy:

```yaml
services:
  web:
    image: ghcr.io/marckohlbrugge/sessy:main
    restart: unless-stopped
    ports:
      - "80:80"
    environment:
      - SECRET_KEY_BASE=your-secret-key-here
      - HTTP_AUTH_USERNAME=admin
      - HTTP_AUTH_PASSWORD=your-secure-password
    volumes:
      - sessy:/rails/storage

volumes:
  sessy:
```
