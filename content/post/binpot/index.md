---
title: "Binpot"
description: "The statically compiled, cross architecture, Docker based, binaries pot."
date: 2021-06-28T11:00:00-06:00
tags: ["docker", "dockerfile", "cross cpu", "go", "buildkit", "vscode"]
---

> [`binpot`](https://github.com/qdm12/binpot) is the repository holding Dockerfiles and Github workflows to statically build binaries for all CPU architectures supported by Docker.

## TL;DR ⏩

1. [Usage](https://github.com/qdm12/binpot#usage):

    ```Dockerfile
    FROM alpine:3.14
    COPY --from=qmcgaw/binpot:helm /bin /usr/local/bin/helm
    ```

1. [Programs available](https://github.com/qdm12/binpot#programs-available)
1. [Search programs on Docker Hub](https://hub.docker.com/r/qmcgaw/binpot/tags)
1. All Docker images and programs are built for every CPU architecture supported by Docker

## Initial situation 🤔

I developed VSCode development containers Dockerfiles for `amd64` only, which covers most machines.

I would simply download necessary pre-built binaries with for example:

```Dockerfile
ARG HELM_VERSION=v3.6.2
RUN wget -qO- "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" | \
    tar -xz -C /usr/local/bin linux-amd64/helm --strip-components=1 && \
    helm version
```

## Support `arm64`

![M1 Chip](m1.svg)

`arm64` made its appearance, especially with the newer Apple M1 chip.
I thus wanted to support it as well for my development containers.

Since most released pre-built binaries don't really follow the same naming convention for the CPU architecture (e.g. `aarch64`, `arm64` or `arm64-v8`), you cannot just use `uname -m` for each of them.

One solution I adopted first was to use shell switch blocks. For example:

```Dockerfile
ARG HELM_VERSION=v3.6.2
ARG TARGETPLATFORM
RUN case "${TARGETPLATFORM}" in \
      linux/amd64) ARCH=amd64; break;; \
      linux/arm64) ARCH=arm64; break;; \
      *) echo "unsupported platform ${TARGETPLATFORM}"; exit 1;; \
    esac && \
    wget -qO- "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" | \
    tar -xz -C /usr/local/bin linux-${ARCH}/helm --strip-components=1 && \
    helm version
```

That worked well, although it added a bit of noise in the Dockerfile.

## Supporting all architectures

Me being me, I wanted to support all the architectures supported by Docker: `amd64`, `arm64`, `armv6`, `armv7`, `s390x` and `ppc64le`.
Sadly `riscv64` for now is not supported by Alpine so I skipped that one.

### Building from source

Since quite a few programs are not already built for some niche architectures like `s390x`, I had to build them from source.

My first approach was to have one build stage per program in each devcontainer Dockerfile.
Each stage would cross compile that program for every platform.

For example I had for the Github CLI in [qmcgaw/basedevcontainer](https://github.com/qdm12/basedevcontainer) ([commit's Dockerfile](https://github.com/qdm12/basedevcontainer/blob/fee615c4d33ca50ad092514cc90acdc4399345a9/alpine.Dockerfile)):

```Dockerfile
FROM gobuilder AS gh
ARG GITHUBCLI_VERSION=v1.10.2
WORKDIR /tmp/build
RUN git clone --depth 1 --branch ${GITHUBCLI_VERSION} https://github.com/cli/cli.git . && \
    GOARCH="$(xcputranslate -field arch -targetplatform ${TARGETPLATFORM})" \
    GOARM="$(xcputranslate -field arm -targetplatform ${TARGETPLATFORM})" \
    go build -trimpath -ldflags "-s -w \
    -X 'github.com/cli/cli/internal/build.Date=$(date +%F)' \
    -X 'github.com/cli/cli/internal/build.Version=${GITHUBCLI_VERSION}' \
    " -o /tmp/gh ./cmd/gh && \
    chmod 500 /tmp/gh
```

followed by a `COPY` for the final image:

```Dockerfile
COPY --from=gh /tmp/gh /usr/local/bin/
```

### Problems

The problem with that was that without (long term) CI layer caching, this would result in:

- Long builds, especially to cross build all programs
- Out of memory errors, since docker's `buildx` (buildkit) would try to compile every program in parallel, as well as for each platform in parallel

Since devcontainer Dockerfile are meant to be changed often with newer development programs versions, this was quite a problem.

I also noticed some programs were cross built for multiple devcontainers in seperate repositories.

## [Binpot](https://github.com/qdm12/binpot)

![Binpot](https://raw.githubusercontent.com/qdm12/binpot/main/binpot.svg)

### Design

I wanted a solution that would:

- deduplicate work between devcontainer repositories
- only rebuild necessary programs
- be Docker oriented

The solution I came up with was to have one repository [github.com/qdm12/binpot](https://github.com/qdm12/binpot), with one directory by program and, for each directory, a corresponding Github Action workflow triggered when this directory is modified.

Each directory contains a Dockerfile describing how to cross build the program and put it on a `scratch` image at the path `/bin`

The basic file structure looks like:

```s
├── .github
|   └── workflows
|       ├── a.yml
|       ├── ...
|       └── z.yml
└── dockerfiles
    ├── a
    |   └── Dockerfile
    ├── ...
    └── z
        └── Dockerfile
```

The workflows takes care to push the cross platform Docker images to Docker hub under the same `qmcgaw/binpot` repository name.

The Docker image tags for `qmcgaw/binpot` follow the following formatting:
    - `:name` for the latest stable version of the program `name`
    - `:name-v0.0.0` for the semver version of the program `name`

All images are built with `buildkit` for all architectures supported by Docker.

#### dlv and `unavailable`

The Go debugging program [`dlv`](https://github.com/go-delve/delve) can only be built for `amd64` and `arm64`, due to its low level nature.
It cannot be built at all on other architectures.

Now building the Docker image only for `amd64` and `arm64` would mean the cross build of my Go development container for other architectures would fail since there would be no image corresponding, for example for `arm/v6`.
For my [Go development container](https://github.com/qdm12/godevcontainer), `dlv` is more of an optional dependency.

I initially used `!#/bin/sh` shell scripts to echo that `dlv` was not supported for this platform.
But to support Docker base images that do not have `sh` (like `scratch`), I wanted to cross compile a tiny Go program to echo this.

This program is named `unavailable` ([github documentation](https://github.com/qdm12/binpot/tree/main/unavailable#unavailable)) and consists of:

- the single Go file [`main.go`](https://github.com/qdm12/binpot/blob/main/unavailable/main.go):

    ```go
    package main

    import (
        "fmt"
        "os"
    )

    var (
        name     = "this program"
        platform = "this platform"
    )

    func main() {
        fmt.Println(name + " is unavailable on " + platform)
        os.Exit(1)
    }
    ```

- a build script [`build.sh`](https://github.com/qdm12/binpot/blob/main/unavailable/build.sh):

    ```sh
    #!/bin/sh

    # Requirements
    # - programs: wget, xcputranslate, go
    # - argument $1: program name
    # - environment variable ${TARGETPLATFORM}

    # Output
    # - Clear current directory
    # - Binary program to /tmp/bin

    echo "Marking ${TARGETPLATFORM} as unavailable"
    echo "Clearing the current directory..."
    rm -rf *
    echo "Building unavailable program..."
    wget -q https://raw.githubusercontent.com/qdm12/binpot/main/unavailable/main.go
    GOARCH="$(xcputranslate translate -field arch -targetplatform ${TARGETPLATFORM})" \
    GOARM="$(xcputranslate translate -field arm -targetplatform ${TARGETPLATFORM})" \
    go build -trimpath \
    -ldflags="-s -w \
    -X 'main.name=${1}' \
    -X 'main.platform=${2}'" \
    -o /tmp/bin main.go
    chmod 500 /tmp/bin
    ```

Together, they can be used in a Docker build stage with for example:

```Dockerfile
RUN \
    # ...
    wget -qO- https://raw.githubusercontent.com/qdm12/binpot/main/unavailable/build.sh | \
       sh -s -- "dlv ${VERSION}" "${TARGETPLATFORM}"
```

💁 [Dlv Dockerfile relevant RUN instruction](https://github.com/qdm12/binpot/blob/main/dockerfiles/dlv/Dockerfile#L19)

That means that for all other architectures where `dlv` cannot be built, this program is built and used instead.

The devcontainer user would then just see `dlv v1.6.1 is unavailable on linux/arm/v6` and the program would exit with exit code `1`.

#### RISV64

All programs in the binpot are for now coded in Go.

Since RISV64 is supported by Docker and Go since [Go 1.14](https://tip.golang.org/doc/go1.14#riscv), I wanted to build binpot binaries for it too.

That worked well for most programs, but some failed, all because of the same [`github.com/prometheus/procfs`](https://github.com/prometheus/procfs) dependency:

- [`golangci-lint v1.41.1`](https://github.com/golangci/golangci-lint/releases/tag/v1.41.1)
- [`helm v3.6.2`](https://github.com/helm/helm/releases/tag/v3.6.2)
- [`buildx v0.5.1`](https://github.com/docker/buildx/releases/tag/v0.5.1)

Since they were using a version before [`v0.3.0`](https://github.com/prometheus/procfs/releases/tag/v0.3.0) which fixed build support for RISCV-64.

My initial workaround was to add in the Dockerfile, before the `go build` instruction:

```Dockerfile
ARG TARGETPLATFORM
RUN \
    # ...
    if [ "${TARGETPLATFORM}" = "linux/riscv64" ]; then go get github.com/prometheus/procfs@v0.6.0 && go mod tidy; fi && \
    # ...
```

To add an indirect transitive dependency on the newer procfs version. That worked well and fixed the 3 builds and their working seems to be as expected as well.

- [@Idez](https://github.com/ldez) was prompt to apply this fix for `golangci-lint` ([issue discussion](https://github.com/golangci/golangci-lint/issues/2079) and [PR](https://github.com/golangci/golangci-lint/pull/2080)). The next release will thus be used in binpot without the `go get` workaround I have currently.
- [@tonistiigi](https://github.com/tonistiigi) also pointed out to me that `buildx` supports riscv64 since [7ecfd3d](https://github.com/docker/buildx/commit/7ecfd3d), although there was no Github release supporting it yet ([issue discussion](https://github.com/docker/buildx/issues/643)). As a result, the latest commit of the master branch is used as its version.
- I made a [pull request](https://github.com/helm/helm/pull/9902) to fix it for `helm`, let's see if it gets merged 👀

### Devcontainer Dockerfiles

I could now simply do in my devcontainer Dockerfiles:

1. At the top, to pin the version with a build argument:

    ```Dockerfile
    ARG BIT_VERSION=v1.1.1
    FROM qmcgaw/binpot:bit-${BIT_VERSION} AS bit
    ```

2. In the final image stage:

    ```Dockerfile
    COPY --from=bit /bin /usr/local/bin/bit
    ```

This would thus copy the binary for the target architecture automatically.

As a result:

- build times were reduced dramatically
- cross build devcontainers for all architectures is now possible and fast

### CI Dockerfiles

For continuous integration Dockerfiles, copying CI tooling such as `golangci-lint` directly from `qmcgaw/binpot` is quite optimal.

It also works no matter what build platform you are running on, which is a plus for open source projects to allow people to build on their Raspberry Pis for example.

For example:

```Dockerfile
ARG GOLANGCI_LINT_VERSION=v1.41.1
ARG BUILDPLATFORM=linux/amd64

FROM --platform=${BUILDPLATFORM} qmcgaw/binpot:golangci-lint-${GOLANGCI_LINT_VERSION} AS golangci-lint

# ...

FROM --platform=${BUILDPLATFORM} golang AS base
# ...
COPY --from=golangci-lint /bin /go/bin/golangci-lint
# ...
```

### Binaries on your host

If you want to use the binary directly on your host, you can do it with Docker.
This has the advantage that it will automatically get the right binary for your host platform.

For example:

```sh
PROGRAM="helm" docker pull "qmcgaw/binpot:$PROGRAM" && \
  containerid="$(docker create qmcgaw/binpot:$PROGRAM)" && \
  docker cp "$containerid:/bin" "/usr/local/bin/$PROGRAM" && \
  docker rm "$containerid"
```

## Future of binpot

For now all programs built in the binpot are written in Go, which offers fast and relatively easy cross compilation.

However, more programs are being integrated that use Rust and C++ as their programming languages, such as `gitstatus`.

If you feel like I should a program to the binpot: [create an issue](https://github.com/qdm12/binpot/issues).

If you like it, feel free to [star it](https://github.com/qdm12/binpot) ⭐
