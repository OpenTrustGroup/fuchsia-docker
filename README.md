# Fuchsia Dev Docker

This repository provides a local Docker environment for Fuchsia development. The
container includes common build tools, SSH access, a non-root `fuchsia` user,
and a persistent local home directory for checkout and build state.

SSH is bound to localhost only and uses public-key authentication by default.

## Files

- `Dockerfile`: Builds the Ubuntu-based Fuchsia development image.
- `docker-compose.yml`: Starts the development container and exposes SSH.
- `docker-compose.kvm.yml`: Optional Compose override that passes `/dev/kvm`
  into the container.
- `docker-entrypoint.sh`: Installs SSH authorized keys at container startup.
- `ssh/authorized_keys`: Local public keys mounted into the container. This file
  is ignored by Git.
- `keys/`: Optional local client key storage. This directory is ignored by Git.
- `fuchsia-home/`: Local home directory for the container's `fuchsia` user.
  This directory is ignored by Git and contains the Fuchsia checkout, compiler
  cache, shell history, Codex state, and other account files.

## Build And Start

Build the image:

```bash
docker compose build
```

Start the container:

```bash
docker compose up -d
```

Check the service:

```bash
docker compose ps
```

The default SSH mapping is:

```text
127.0.0.1:2222 -> container port 22
```

## SSH Login

If you are using the generated key created for this project, connect with:

```bash
./fuchsia-ssh
```

To use your own SSH key instead, copy your public key into `ssh/authorized_keys`:

```bash
cp ~/.ssh/id_ed25519.pub ssh/authorized_keys
docker compose up -d --force-recreate
```

Then connect with your matching private key:

```bash
SSH_KEY=~/.ssh/id_ed25519 ./fuchsia-ssh
```

You can also place one or more `*.pub` files in `ssh/`; the entrypoint will
combine them into the container user's `authorized_keys` file.

## Development Workflow

Open a shell over SSH:

```bash
./fuchsia-ssh
```

Open a shell with X11 forwarding enabled:

```bash
./fuchsia-ssh --x11
```

Use trusted X11 forwarding for tools that need it:

```bash
./fuchsia-ssh --trusted-x11
```

Firefox is installed in the image from Mozilla's APT repository. Launch it over
X11 forwarding with:

```bash
./fuchsia-ssh --trusted-x11 firefox
```

Enable KVM-backed emulator acceleration on hosts that expose `/dev/kvm`:

```bash
test -e /dev/kvm
docker compose -f docker-compose.yml -f docker-compose.kvm.yml up -d --build --force-recreate
```

When `/dev/kvm` is mounted, the entrypoint adds the container user to a group
matching the device's group ID before starting SSH. Open a new SSH session after
recreating the container so the login has the updated group membership.

Run a command over SSH:

```bash
./fuchsia-ssh 'cd ~/fuchsia && git status --short --branch'
```

Inside the container, the default development paths are:

```text
FUCHSIA_DIR=/home/fuchsia/fuchsia
CCACHE_DIR=/home/fuchsia/.cache/ccache
```

The `fuchsia` user's home directory is bind-mounted from `./fuchsia-home`, so
the Fuchsia checkout in `~/fuchsia`, the compiler cache in `~/.cache/ccache`,
shell history, Codex state, and other account files persist across container
recreation.

Codex CLI is installed in the image and available as `codex` inside the
container. After logging in over SSH, authenticate once with:

```bash
codex login
```

You can also store an API key login with:

```bash
printenv OPENAI_API_KEY | codex login --with-api-key
```

## Configuration

The Compose file supports these environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `DEV_USER` | `fuchsia` | Container user name |
| `DEV_UID` | `1000` | Container user UID |
| `DEV_GID` | `1000` | Container user GID |
| `SSH_PORT` | `2222` | Localhost SSH port |
| `SSH_KEY` | `keys/fuchsia_dev_ed25519` | Client private key for `./fuchsia-ssh` |
| `SSH_X11` | unset | Enable untrusted X11 forwarding for `./fuchsia-ssh` |
| `SSH_TRUSTED_X11` | unset | Enable trusted X11 forwarding for `./fuchsia-ssh` |

Example:

```bash
SSH_PORT=2022 DEV_UID="$(id -u)" DEV_GID="$(id -g)" docker compose up -d --build
```

## Stop Or Remove

Stop the container:

```bash
docker compose down
```

Remove the container:

```bash
docker compose down
```

The persisted home directory contains the checkout and ccache. Remove it only
when you intentionally want to delete local account and build state:

```bash
rm -rf fuchsia-home
```

## Security Notes

- SSH listens on `127.0.0.1` only, not on all network interfaces.
- Password SSH login is disabled in the image.
- X11 forwarding requires a host X server. Use `--trusted-x11` only for tools
  that need trusted access to your X session.
- `keys/`, `ssh/authorized_keys`, and `fuchsia-home/` are ignored by Git to
  avoid committing private or machine-specific account material.
