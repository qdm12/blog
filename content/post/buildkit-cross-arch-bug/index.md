---
title: "Buildkit cross architecture building bug... or feature?"
description: ""
date: 2021-06-20T11:00:00-06:00
tags: ["docker", "dockerfile", "cross cpu", "buildkit"]
---


`buildkit` is now included with Docker Desktop and the Docker `buildx` plugin.

We can now build an image for multiple CPU architectures by using the flag `--platform` in the `docker buildx build` command.
For example `docker buildx build --platform=linux/amd64,linux/arm64 .`.

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

Now in my particular situation, I have developed a small program called [`xcputranslate`](https://github.com/qdm12/xcputranslate) to convert strings such as `linux/arm/v7` to `arm` and `7` for `GOARCH` and `GOARM` for go builds, without relying on shell scripting. The static binary program is built for every architecture and pushed in a scratch based image on Docker Hub as `qmcgaw/xcputranslate`.

The Dockerfile above would be changed to:

```Dockerfile
FROM --platform=$BUILDPLATFORM golang:1.16-alpine3.13 AS builder
ENV CGO_ENABLED=0
RUN apk add --no-cache git
COPY --from=qmcgaw/xcputranslate:v0.6.0 /xcputranslate /usr/local/bin/xcputranslate
WORKDIR /tmp/build
COPY go.mod go.sum
RUN go mod download
COPY . .
ARG TARGETPLATFORM
RUN GOARCH="$(xcputranslate translate -targetplatform ${TARGETPLATFORM} -language golang -field arch)" \
    GOARM="$(xcputranslate translate -targetplatform ${TARGETPLATFORM} -language golang -field arm)" \
    go build
```

That works well, but it seemed buildkit was breaking the common build platform build in N parallel builds for the N target platforms from:

```Dockerfile
COPY --from=qmcgaw/xcputranslate:v0.6.0 /xcputranslate /usr/local/bin/xcputranslate
```

That means it will run:

```Dockerfile
WORKDIR /tmp/build
COPY go.mod go.sum
RUN go mod download
COPY . .
```

N times, and I thought it was doing the exact same thing N times.

## Enter the rabbit hole

I thought the `COPY` instruction was copying the binary matching the stage running platform (`${BUILDPLATFORM}` in our case).

So if we are running:

```Dockerfile
FROM --platform=linux/amd64 golang:1.16-alpine3.13 AS builder
# ...
COPY --from=qmcgaw/xcputranslate:v0.6.0 /xcputranslate /usr/local/bin/xcputranslate
RUN xcputranslate --help
```

It seemed obvious to me `xcputranslate` was the binary from the `linux/amd64` image and not the target platform image.
You cannot run an `arm` binary on an `amd64` stage... It turned out that buildkit was *ahead of its time!*

I have exchanged with [tonistiigi](https://github.com/tonistiigi) on [Docker's buildkit Slack](https://dockercommunity.slack.com/archives/C7S7A40MP/p1623804144116300) for a few days to clarify all this.

With buildkit, `COPY` pulls **from the target platform** image and not from the platform of the stage.
And buildkit is clever enough to detect this and split the build N times, with an emulation for each parallel build.

Now the state of my Dockerfile was thus terrible since I was running not only the N parallel builds, but on top of that they were emulated, making the overall build slowww...

## Solution

The solution is actually quite simple.

In my case, I just had to **alias the image** by specifying the `--from` with the `BUILDPLATFORM`

```Dockerfile
FROM --from=${BUILDPLATFORM} qmcgaw/xcputranslate:v0.6.0 AS xcputranslate
```

And then change the `COPY` instruction to:

```Dockerfile
COPY --from=xcputranslate /xcputranslate /usr/local/bin/xcputranslate
```

That made my Docker cross builds much quicker and efficient, only splitting the build in N emulated parallel builds when reaching the `ARG TARGETPLATFORM` instruction.

🎉🎉🎉 Success!!! 🎉🎉🎉

Special thanks to [tonistiigi](https://github.com/tonistiigi) for his help!
