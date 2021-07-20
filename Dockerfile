ARG BUILDPLATFORM=linux/amd64

ARG ALPINE_VERSION=3.14

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS hugo
WORKDIR /tmp/hugo
RUN apk add --no-cache hugo
ENV HUGO_ENV=production
COPY . .
RUN hugo --minify

FROM qmcgaw/srv
ENV HTTP_SERVER_ROOT_URL=/blog
COPY --from=hugo --chown=1000 /tmp/hugo/public /srv
