---
title: "VSCode dev container with Podman and WSL"
description: "How to skip 3 days of configuration hell to have dev containers with Podman and WSL"
date: 2024-03-18T08:00:00+01:00
tags: ["podman", "vscode", "container", "development", "wsl"]
---

I have been running VSCode development containers for many years.
My main machine running Windows 10, I was using **Docker Desktop** to inject Docker in WSL.
And that has been nothing but slow and steady troubles, so it was time to migrate to **Podman**.

## Problems with Docker Desktop

- Slow to start
- Not that reliable, it can crash at start, stop or while running rarely
- It seems to sometimes crash WSL which won't even stop with `wsl --shutdown`

## Why Podman

- **Daemon less** so it can't really crash unless being called for something
- No need to install it on the host system, installing in WSL is enough
- **Rootless**

## Prerequisites

My configuration is as follows:

- Windows 10 host 10.0.19045
- WSL 2.1.5.0
- Ubuntu 22.04.3 LTS running in WSL
- VSCode 1.87.2
- [VSCode dev container extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) v0.348.0

## Installation

### Podman

We could install Podman 3.x.x from Ubuntu default package repositories, but Podman 4.x.x is a better choice especially when it comes to networking
since it comes with `netavark` and `aardvark-dns`. To install Podman 4.x.x we will use the OpenSUSE unstable Unbutu repositories.

```sh
key_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_$(lsb_release -r -s)/Release.key"
curl -fsSL $key_url | gpg --yes --dearmor | sudo tee /etc/apt/trusted.gpg.d/devel_kubic_libcontainers_unstable.gpg > /dev/null
sources_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/unstable/xUbuntu_$(lsb_release -r -s)/"
sources_path="/etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list"
sudo echo "deb $sources_url /" >> $sources_path
sudo apt-get update
sudo apt-get install -y podman
```

Configure Podman to use the `netavark` network backend by editing (with `sudo`) `/etc/containers/containers.conf` and
adding `network_backend = "netavark"` to the `[network]` section.

Since Podman will use the *netavark* network backend, we can remove CNI related configuration files created:

```sh
sudo rm -r /etc/cni
```

Edit (with `sudo`) `/etc/containers/registries.conf` and change `unqualified-search-registries` to be just `["docker.io"]` (or `[]`), otherwise
the non-interactive VSCode dev container extension console will prompt to pick the right registry when pulling an image.

Finally, set the VSCode user setting `dev.containers.dockerPath` to `/usr/bin/podman`.

### Podman socket

VSCode dev container extension requires a socket to interact with Podman, like it does with Docker.

To start a Podman socket, we will use `systemd`.
Edit the file `/etc/wsl.conf` and add or set:

```ini
[boot]
systemd=true
```

Exit WSL, shut it down with `wsl --shutdown`, and restart it with `wsl`.

Now copy the systemd unit files to your user directory with:

```sh
mkdir -p ~/.config/systemd/user/
cp /usr/lib/systemd/user/podman.service ~/.config/systemd/user/podman.service
cp /usr/lib/systemd/user/podman.socket ~/.config/systemd/user/podman.socket
```

And then enable and start the Podman socket with:

```sh
systemctl --user enable --now podman.socket
```

⚠️ Make sure to run this without `sudo` to have a rootless Podman socket.

This should start a Podman socket and you can check it's there with:

```sh
ls -l /run/user/$(id -u)/podman/podman.sock
```

Finally, to have VSCode automatically pickup the Podman socket, you can do:

```sh
sudo cp /run/user/$(id -u)/podman/podman.sock /var/run/docker.sock
sudo chown $(whoami) /var/run/docker.sock
```

Or alternatively set `"docker.host": "unix:///run/user/1000/podman/podman.sock"` in your VSCode JSON user settings, where `1000` is your WSL user id `id -u`.

### Compose

Unfortunately, `podman-compose` does not play nice with VSCode dev container extension, giving a `Dockerfile does not exist` error,
so we have to stick with `docker-compose`, which you can install using:

```sh
sudo apt-get install -y docker-compose
```

You may need to set it in VSCode user settings with `"dev.containers.dockerComposePath": "/usr/bin/docker-compose"`.

### Testing it out

Download [devtainr](https://github.com/qdm12/devtainr) to setup a development container `.devcontainer` directory.

```sh
sudo wget -qO /usr/local/bin/devtainr https://github.com/qdm12/devtainr/releases/download/v0.6.0/devtainr_0.6.0_linux_amd64
sudo chmod +x /usr/local/bin/devtainr
```

Create a new directory, run `devtainr` and open VSCode in it:

```sh
mkdir ~/test
cd ~/test
devtainr -dev base
code .
```

Then open the VSCode command palette and choose **Dev Containers: Open Folder in Container...** and pick `~/test`.

### Watch out for

- Even if your dev container runs as root, the files must be owned by the non root user of WSL, since root within the container is not root on WSL Ubuntu.
- If you enable or start the socket with `sudo`, it creates a root Podman socket, not a rootless Podman socket.
