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

## Run it

You can run it with the [docker-compose.yml](docker-compose.yml) provided or with:

```sh
docker run -it --rm -p 8000:8000/tcp qmcgaw/blog
```

## Features

The Docker image is based on [qmcgaw/srv](https://github.com/qdm12/srv) which has [several features](https://github.com/qdm12/srv#features) such as Prometheus metrics.

The blog itself in this repository is just based on static Markdown/SVG/JPG files.

The Docker build takes care of trans-compiling them with Hugo.

## TODOs

- Like button counter
- Subscribe by email

### Posts

#### Programming

- When Docker doesn't behave the same
  - No support for capabilities (old Kernel)
  - libseccomp2 and Alpine >= 3.13 on 32 bit, especially Raspbian
  - libcap and setcap with older Kernels
- Fastest thread safe uniformly distributed number generation
- Implementing DoH and DoT `net.Resolver` in Go
- Gluetun
- Rust development container
- Rust cross compilation for Docker
- Rust: glibc vs musl
  - See [Reddit post](https://www.reddit.com/r/rust/comments/oh2k8l/rust_musl_and_glibc_in_2021/)
- `goshutdown`
- xcputranslate sleep feature
  - avoid OOM
- Generated files:
  - generate them in the CI and commit them by the CI; or
  - generate them in the CI and fail if it does not match, leave the commit responsibility to the developer

#### Not done yet™️

- Implementing DNSSEC in Go
- Cross compiling Rust for OSX and Windows
  - See [this](https://wapl.es/rust/2019/02/17/rust-cross-compile-linux-to-macos.html)
- `go build` using large amount of memory with large hardcoded values in Go files, solved by using `embed`
- Encapsulation of metrics interfaces in a Go program
- Gotree
- `go.mod` check for useless dependencies: [write a Go linter for it](https://disaev.me/p/writing-useful-go-analysis-linter/)
- A Traefik-like firewall for Docker containers

#### Not programming

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
- Will we have more differentiation with time or not?
  - religions?
  - languages?
  - states?
  - more planets?
  - compared to previous history?
  - easier communication today than before
  - intra planet communication?
- Would we get bored of living forever?
  - We do repeat tasks most of our life already
