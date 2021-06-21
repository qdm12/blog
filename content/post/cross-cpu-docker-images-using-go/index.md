---
title: "Cross CPU docker images using Go"
description: "How to write your Dockerfile to cross compile Go applications"
date: 2021-06-04T15:00:00-06:00
tags: ["docker", "go", "dockerfile", "cross cpu", "ci"]
---

Building cross CPU Docker images for Go programs is not a trivial task.

With the excellent Go compiler and the recent improvements of Docker building, quite an advanced setup can be achieved to build Docker images for all CPU architectures supported by Docker and Go.

## What we'll do

We will design a *Dockerfile* cross building a simple Go program for Docker images supporting multiple CPU architectures.

The aim is to have the statically compiled Go program in a final Docker image based on the `alpine:3.13` image.

## Initial setup

You should have this minimal file structure at the end of this section:

```s
.
├── Dockerfile
└── main.go
```

### Go program

Our Go program will just be `main.go`:

```go
package mainz

import "fmt"

func main() {
	fmt.Println("Hello world")
}

```

### Dockerfile

Let's start with an initial `Dockerfile`

```Dockerfile
ARG GO_VERSION=1.16
ARG ALPINE_VERSION=3.13

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS gobuilder
WORKDIR /tmp/build
COPY main.go .
RUN go build -o app

FROM alpine:${ALPINE_VERSION}
ENTRYPOINT [ "/usr/local/bin/app" ]
COPY --from=gobuilder /tmp/build/app /usr/local/bin/app
```

## Go cross CPU building

Not only the Go compiler `gc` is very fast, it's also able to cross compile programs very easily.

If you want to compile your program for `arm64` for example, you just need to set `GOARCH=arm64`.

For example:

```sh
GOARCH=arm64 go build -o app
```

## Docker cross CPU building

Docker can cross build docker images using the `--platform` flag.

For example:

```sh
docker build --platform=linux/arm64 .
```

will build our image for `arm64`.

However, this runs `go build` by fully emulating the build process using QEMU.

Instead, we should take advantage of Go's cross CPU building which is much faster.

## `BUILDPLATFORM` build argument

The `BUILDPLATFORM` build argument is injected by `docker build` when cross building with the `--platform` flag.

It is the CPU architecture you are building on, for example `linux/amd64`.

Modify your Dockerfile by adding `ARG BUILDPLATFORM=linux/amd4` as well as `--platform=$BUILDPLATFORM` between the `FROM` and the image name for our Go builder stage.

Your Dockerfile should look like:

```Dockerfile
# ...

ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS gobuilder
# ...
```

Small note that you have to set `BUILDPLATFORM` to a default for compatibility reasons.

This tells `docker build` to run the `gobuilder` stage on your native platform.

Because we leave the last stage without precising `FROM --platform=...`, this one however will be emulated on the target platform.

Now the problem left is that the Go binary built will always be built for your build platform, and not the target platform.

This is where `TARGETPLATFORM`, `GOARCH` and `GOARM` come into play!

## `TARGETPLATFORM` build argument

The `TARGETPLATFORM` build argument is injected by `docker build` when cross building.

It is your target CPU architecture, for example `linux/arm/v7` when using `--platform=linux/arm/v7`

Modify your Dockerfile by adding `ARG TARGETPLATFORM` inside the `gobuilder` stage.

Your Dockerfile should look like:

```Dockerfile
# ...

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS gobuilder
WORKDIR /tmp/build
ARG TARGETPLATFORM
# ...
```

Now we want to transform `TARGETPLATFORM` in `GOARCH` and `GOARM`.

But here's the problem, `TARGETPLATFORM` can be one of:

- `linux/amd64`
- `linux/386`
- `linux/arm64`
- `linux/arm/v7`
- `linux/arm/v6`
- `linux/ppc64le`
- `linux/s390x`
- `linux/riscv64`

For ARMv6 and ARMv7, Go expected `GOARCH=arm` and `GOARM=6` or `GOARM=7`.
To convert from one string to the two others, I wrote a small Go program: [xcputranslate](https://github.com/qdm12/xcputranslate)

> A little Go static binary tool to convert Docker's buildx CPU architectures such as linux/arm/v7 to strings for other compilers.

That way it removes a lot of potential horribly nested shell scripting in your Dockerfile.

Use it in your Dockerfile like so:

```Dockerfile
FROM --platform=$BUILDPLATFORM qmcgaw/xcputranslate:v0.6.0 AS xcputranslate

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS gobuilder
COPY --from=xcputranslate /xcputranslate /usr/local/bin/xcputranslate
WORKDIR /tmp/build
COPY main.go .
RUN GOARCH="$(xcputranslate translate -targetplatform ${TARGETPLATFORM}  -language golang -field arch)" \
    GOARM="$(xcputranslate translate -targetplatform ${TARGETPLATFORM} -language golang -field arm)" \
    go build -o app
```

💁 Note that `FROM --platform=$BUILDPLATFORM qmcgaw/xcputranslate:v0.6.0 AS xcputranslate` pulls the binary for your build platform automagically, since there is an image built for each CPU architecture.

😢 Also note you cannot set `GOARCH` or `GOARM` as `ENV` or `ARG` in your Dockerfile since these are dynamically evaluated at build time.

## Final Dockerfile

Your Dockerfile should be now:

```Dockerfile
ARG GO_VERSION=1.16
ARG ALPINE_VERSION=3.13

ARG BUILDPLATFORM=linux/amd64

FROM --platform=$BUILDPLATFORM qmcgaw/xcputranslate:v0.6.0 AS xcputranslate

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS gobuilder
COPY --from=xcputranslate /xcputranslate /usr/local/bin/xcputranslate
WORKDIR /tmp/build
COPY main.go .
RUN GOARCH="$(xcputranslate translate -targetplatform ${TARGETPLATFORM}  -language golang -field arch)" \
    GOARM="$(xcputranslate translate -targetplatform ${TARGETPLATFORM} -language golang -field arm)" \
    go build -o app

FROM alpine:${ALPINE_VERSION}
ENTRYPOINT [ "/usr/local/bin/app" ]
COPY --from=gobuilder /tmp/build/app /usr/local/bin/app
```

## Try it

Let's build it for the armv7 architecture for example:

```sh
docker build -t goarmv7 --platform=linux/arm/v7 .
```

Run it with emulation:

```sh
docker run -it --rm --platform=linux/arm/v7 goarmv7
```

And that should print out `Hello world` 🚀

## Conclusion

You can now build cross CPU architecture Docker images by taking advantage of the Go cross compiler.

That reduced my Docker build times from 15 minutes to 5 minutes for [github.com/qdm12/gluetun](https://github.com/qdm12/gluetun).

Enjoy the time saved!
