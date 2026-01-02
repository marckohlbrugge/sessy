## Deploying with Dokku

This guide covers deploying Sessy to a server running [Dokku](https://dokku.com/).

### 1. Install Dokku

Follow the quick-start instructions [here](https://dokku.com/) to install Dokku on your server.

### 2. Create Sessy as a Dokku app

Run the following script which will create Sessy as a Dokku app, and make a fix to the permissions for the directory it runs in to make it compatible with Dokku:

```bash
dokku apps:create sessy

# Configure exposed ports - use any host-port you'd like. Mapping format is protocol:host-port:container-port
dokku ports:add sessy http:80:80

# Configure mounted storage
sudo -u dokku mkdir -p /var/lib/dokku/data/storage/sessy/sessy
dokku storage:mount sessy /var/lib/dokku/data/storage/sessy/sessy:/rails/storage

# IMPORTANT: Manually fix mounted dir permissions since Sessy uses uid 1000 for security reasons
sudo chown -R 1000:1000 /var/lib/dokku/data/storage/sessy/sessy
```

### 3. Configure required environment variables (and any others you'd like to change)
```
# Make sure to set these two environment variables:
dokku config:set --no-restart sessy SECRET_KEY_BASE="$(openssl rand -hex 64)"
dokku config:set --no-restart sessy DISABLE_SSL="true"

# And add any other environment variables you want to modify here, for example:
# dokku config:set --no-restart sessy HTTP_AUTH_USERNAME="some_username"
# dokku config:set --no-restart sessy HTTP_AUTH_PASSWORD="some_secure_password"
```

### 4. Deploy

For the initial deployment:

```sh
dokku git:from-image sessy ghcr.io/marckohlbrugge/sessy:main
```

### 5. Update to Latest Version

To update Sessy to the latest version, first find the latest version [here](https://github.com/marckohlbrugge/sessy/pkgs/container/sessy/versions?filters%5Bversion_type%5D=tagged). It will be the version at the top of the list.

Then issue this command to update the deployment to a specific sha found above. For example, to update to version `sha256-8302dacf28b75c8c2e411269305ca4f3a39bd5265aa269bf3b2acbb78088c527` use:

```sh
dokku git:from-image sessy ghcr.io/marckohlbrugge/sessy:sha256-8302dacf28b75c8c2e411269305ca4f3a39bd5265aa269bf3b2acbb78088c527
```
