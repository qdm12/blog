---
title: "Docker without root"
description: "How to build Docker images and run containers without root"
date: 2021-06-04T19:00:00-06:00
tags: ["docker", "dockerfile", "security"]
---

A lot of developers are not aware running a Docker container as root is risky security wise.

A container is still isolated with the isolation of LXC, but running as root means it's running as the same root as the on the host.

An attacker gaining access to the container can thus do some damage since he has root access.

There are multiple ways to avoid running as root but there are also many challenges that we address in the following.

## Build images

### The `USER` instruction

For final images using an OS such as Alpine or Debian, you can usually add a line to your Dockerfile:

```Dockerfile
USER nobody
```

You can specify another user that is part of the users of the system, you can check with `cut -d: -f1 /etc/passwd`.

Alternatively you can specify a user ID for example with:

```Dockerfile
USER 1000
```

This is especially useful for images without an OS such as [scratch](https://hub.docker.com/_/scratch).

⚠️ You should have your `USER` instruction at the end since it will prevent you from running commands requiring `root` such as package manager instructions.

### Change ownership and permissions of files in the image

For every directory and programs that would be used in the container, you need to now be careful about ownership and permissions.

For example, let's assume our image has an application at `/usr/local/bin/app` and will write to the directory `/var/app`.

You should thus have in your Dockerfile:

```Dockerfile
RUN chown 1000 /usr/local/bin/app && \
    chmod 500 /usr/local/bin/app
RUN mkdir /var/app && \
    chown 1000 /var/app && \
    chmod 700 /var/app
```

💁 note that running `chown` or `chmod` will double the size of the `/usr/local/bin/app` if you run it in a different layer in the final image.

A solution is to run the `chmod` and `chown` instructions in another Docker stage, for example:

```Dockerfile
ARG ALPINE_VERSION=3.13

FROM alpine:${ALPINE_VERSION} AS builder
WORKDIR /tmp
# we copy the binary to simplify the Dockerfile here
COPY app .
RUN chown 1000 app && chmod 500 app

FROM alpine:${ALPINE_VERSION}
COPY --from=builder /tmp/app /usr/local/bin/app
# ...
```

And then the ownership and permissions will be carried from that `builder` stage to the final image.

### Change your listening port

Do not make your application listen on any of the privileged port, that is a port between `1` and `1024`.

Otherwise it will fail binding its port by default since your container will running without root.

I usually make an HTTP server application listen on port `8080` for example.

Now, there can be exceptions, notably a **DNS server** which **has to listen on port 53** in certain situations.

To do so, you need to install `libcap` and use `setcap` to set the capability required on the binary program.

For example on Alpine, where your application is `/usr/local/bin/app`:

```Dockerfile
RUN apk --no-cache add libcap && \
    setcap 'cap_net_bind_service=+ep' /usr/local/bin/app && \
    apk del libcap
```

As for the previous section, you can also run this in the previous stage to avoid duplicating data across layers in the final image.
That is also quite useful if your final image is based on `scratch` since you cannot run `setcap` on the `scratch` Docker image.

## Run containers

To run a container running without root, you can either:

1. run the container with `--user=1000` for example
2. run the container of an image already running without root

Note that for 1, this can be risky since the Docker image might not be designed to run without root, in terms of listening port and/or file permissions.

The main problem arising from running containers without root is that bind mounts will have to match the user ID of the running container.

You will thus have to document for the user of your Docker image that he has to change the ownership and permission of the directories on his host to bind mount them.

For example:

```sh
chown 1000 /path/on/the/host
chmod 700 /path/on/the/host
```

In order to bind mount it with `-v /path/on/the/host:/var/app`.

An alternative would be to use Docker volumes with `-v app_volume:/var/app` for example, which would keep the permission and ownership set on the directory in the image.

## When you should run as root

These are the few cases where you **should run the container as root**:

- File servers (e.g. NFS, SMB, SFTP) since they will most likely access files with different ownership and permissions
- VPN applications since they often need to fiddle with the host interfaces
