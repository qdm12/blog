---
title: "Buildkit cross architecture building bug"
description: ""
date: 2021-06-20T11:00:00-06:00
tags: ["docker", "dockerfile", "cross cpu", "buildkit"]
---


`buildkit` is now included with Docker Desktop and the Docker `buildx` plugin.

We can now build an image for multiple CPU architectures by using the flag `--platform` in our `docker buildx build` command.
For example `--platform=linux/amd64,linux/arm64`.

You can however keep on using the native build platform by using the `--platform=${BUILDPLATFORM}` flag in your Dockerfile's `FROM` instruction.

For example:

```Dockerfile
FROM --platform=${BUILDPLATFORM} golang:1.16-alpine3.13 AS builder
```

You will usually specify the `TARGETPLATFORM` argument further down in the Docker build stage block.

For example, for Go programs, you would have:

```Dockerfile
FROM --platform=$BUILDPLATFORM golang:1.16-alpine3.13 AS builder
ENV CGO_ENABLED=0
RUN apk add --no-cache git
WORKDIR /tmp/build
COPY go.mod go.sum
RUN go mod download
COPY . .
ARG TARGETPLATFORM
RUN GOARCH="${TARGETPLATFORM##linux/}" \
    go build
```

This has the advantage that you can use the native CPU platform without emulation and use the programming language cross building capabilities
which are usually, if not always, faster.

In this case, all the intructions down to `ARG TARGETPLATFORM` will run only once on the native platform.

They will split for the N target architectures at the `ARG TARGETPLATFORM` instruction, building for each architecture in parallel but all using the native architecture to build.

If you do not have Docker layer caching, which is usually the case on CIs, this saves a tremendous amount of time especially with the dependencies (`go mod download`).

## Bug

Now in my particular situation, I have development a small program called [`xcputranslate`](https://github.com/qdm12/xcputranslate) to convert strings such as `linux/arm/v7` to `arm` and `7` for `GOARCH` and `GOARM` for go builds, without relying on shell scripting. The static binary program is built for every architecture and pushed in a scratch based image on Docker Hub as `qmcgaw/xcputranslate`.

The Dockerfile above would be changed to:

```Dockerfile
FROM --platform=$BUILDPLATFORM golang:1.16-alpine3.13 AS builder
ENV CGO_ENABLED=0
RUN apk add --no-cache git
COPY --from=qmcgaw/xcputranslate /xcputranslate /usr/local/bin/xcputranslate
WORKDIR /tmp/build
COPY go.mod go.sum
RUN go mod download
COPY . .
ARG TARGETPLATFORM
RUN GOARCH="$(xcputranslate -targetplatform ${TARGETPLATFORM} -language golang -field arch)" \
    GOARM="$(xcputranslate -targetplatform ${TARGETPLATFORM} -language golang -field arm)" \
    go build
```

That works well, pulling the right binary depending on your build platform using the `qmcgaw/xcputranslate` image.

Now there seems to be a bug with buildkit, where the

```Dockerfile
COPY --from=qmcgaw/xcputranslate /xcputranslate /usr/local/bin/xcputranslate
```

actually breaks the common build, and from this instruction, it will run N times for the N target platforms.
That means it will run:

```Dockerfile
WORKDIR /tmp/build
COPY go.mod go.sum
RUN go mod download
COPY . .
```

N times, although these are exactly the same.

## Workarounds

### COPY later

The easiest workaround is to copy the (less than 2MB) binary right before `ARG TARGETPLATFORM`, so that only the COPY instruction is ran N times.

The tiny issue is that xcputranslate will not be cached in the build if you have layer caching enabled, since it's after the COPY of the source code.

### Download the binary

Another workaround is to not use `COPY` but instead download the binary using for example:

```Dockerfile
RUN wget -qO /usr/local/bin/xcputranslate https://github.com/qdm12/xcputranslate/releases/download/v0.5.0/xcputranslate_0.5.0_linux_amd64 && \
    chmod 500 /usr/local/bin/xcputranslate
```

This works well for caching purposes, but you have to manage to specify the right build platform when downloading the binary without `xcputranslate`.

## Solution

Waiting on it 😄
