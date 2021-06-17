---
title: "Suggestion on how to improve cross CPU docker builds with the Dockerfile"
description: ""
date: 2021-06-14T11:00:00-06:00
tags: ["docker", "dockerfile", "cross cpu"]
---

With Docker `buildx`, we can now build an image for multiple CPU architectures by using the flag `--platform` in our `docker buildx build` command.
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

## Problem

If you do not have Docker layer caching, which is usually the case on CIs, all the following instructions:

```Dockerfile
FROM --platform=$BUILDPLATFORM golang:1.16-alpine3.13 AS builder
ENV CGO_ENABLED=0
RUN apk add --no-cache git
WORKDIR /tmp/build
COPY go.mod go.sum
RUN go mod download
COPY . .
```

are repeated for each CPU architecture you build for.

But they are all the same, for the same build platform architecture.

On top of that, downloading dependencies is quite time consuming, and that gets worst with languages other than Go.

Note that the final cross build instructions using `TARGETPLATFORM`:

```Dockerfile
ARG TARGETPLATFORM
RUN GOARCH="${TARGETPLATFORM##linux/}" \
    go build
```

should be **ran** for every target CPU architecture.

## Solution

Ideally, `docker build` should detect instructions between:

1. The start of a stage using `--platform=${BUILDPLATFORM}` in its `FROM` instruction
1. The build argument `ARG TARGETPLATFORM`

And run all of them only once and only then branch out the buld for every CPU architectures.

Additionally, `docker build` should detect dependencies on `COPY`s from previous stages running without `--platform=${BUILDPLATFORM}` or that used `ARG TARGETPLATFORM`.
If such `COPY`s are present, the build branching out should start at the first such `COPY` if it did not yet.

## Example

### Branching out with `TARGETPLATFORM`

```Dockerfile
ARG BUILDPLATFORM=linux/amd64

FROM --platform=${BUILDPLATFORM} alpine AS builder
ARG BUILDPLATFORM
RUN echo "Downloading dependencies on ${BUILDPLATFORM}..."
RUN touch /tmp/dependencies
ARG TARGETPLATFORM
RUN echo "Cross building on ${BUILDPLATFORM} for ${TARGETPLATFORM}..."
RUN touch /tmp/app

FROM scratch
COPY --from=builder /tmp/app /app
```

In this case we have a `builder` stage.

The instructions:

```Dockerfile
ARG BUILDPLATFORM
RUN echo "Downloading dependencies on ${BUILDPLATFORM}..."
RUN touch /tmp/dependencies
```

should run only once and the instructions below:

```Dockerfile
ARG TARGETPLATFORM
RUN echo "Cross building on ${BUILDPLATFORM} for ${TARGETPLATFORM}..."
RUN touch /tmp/app
```

Should run for every CPU architectures.

The final stage `FROM scratch`:

1. Does not precise `--from=${BUILDPLATFORM}` so it should run for each CPU architecture (as it does today already)
1. COPY from the `builder` stage which branched out since it used `ARG TARGETPLATFORM`

### Branching out with `COPY`

```Dockerfile
ARG BUILDPLATFORM=linux/amd64

FROM alpine AS tplatform
RUN touch /tmp/tplatform

FROM --platform=${BUILDPLATFORM} alpine AS builder
ARG BUILDPLATFORM
COPY --from=tplatform /tmp/tplatform /tmp/tplatform
RUN echo "Downloading dependencies on ${BUILDPLATFORM}..."
RUN touch /tmp/dependencies
ARG TARGETPLATFORM
RUN echo "Cross building on ${BUILDPLATFORM} for ${TARGETPLATFORM}..."
RUN touch /tmp/app

FROM scratch
COPY --from=builder /tmp/app /app
```

In this case we have a `tplatform` stage running on the target platform through emulation.

The next stage, `builder` should branch out its build at the `COPY` instruction since `tplatform` ran on the target platform

```Dockerfile
COPY --from=tplatform /tmp/tplatform /tmp/tplatform
```

The rest of instructions should then continue in their branches until the end.
