# Blog

Static blog using Hugo

## Automated CI/CD

The blog is hosted on my server as a Docker container.

Each push to the `main` branch on this repository triggers a Github Actions CI build which pushes a Docker image to Docker Hub to the `qmcgaw/blog` repository.

My server uses [watchtower](https://containrrr.dev/watchtower) to automatically update the [`qmcgaw/blog`](https://hub.docker.com/r/qmcgaw/blog) Docker image associated container automatically.

## Build locally

You can build the Docker image locally with

```sh
docker build -t qmcgaw/blog .
```

## Features

The Docker image is based on [qmcgaw/srv](https://github.com/qdm12/srv) which has [several features](https://github.com/qdm12/srv#features) such as Prometheus metrics.

The blog itself in this repository is just based on static Markdown/SVG/JPG files.

The Docker build takes care of trans-compiling them with Hugo.

## TODOs

### Posts

- `goshutdown`
- xcputranslate sleep feature
  - avoid OOM
- `go build` using large amount of memory with large hardcoded values in Go files, solved by using `embed`
- `go.mod` check for useless dependencies: [write a Go linter for it](https://disaev.me/p/writing-useful-go-analysis-linter/)
- Generated files:
  - generate them in the CI and commit them by the CI; or
  - generate them in the CI and fail if it does not match, leave the commit responsibility to the developer
- Encapsulation of metrics interfaces in a Go program
- Gotree
- A Traefik-like firewall for Docker containers
- Comparison of humans and computers
  - Von Neumann architecture
  - Neuromorphic architecture
  - Caching / Training
  - Learn from past to anticipate future better
  - Are humans more stream oriented or more stateful? e.g. our past is an approximate memory and our future is a prediction based on logic and emotions
  - Human addictions when we get better (sports, gaming, even work): do machines have that too?
    - We enjoy being good at something, do machines do it as well?
  - Some like to learn new things, do machines have this?
  - How does AI gets closer to humans.
