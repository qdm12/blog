---
title: "Open source Docker image tagging strategies"
description: "How to do releases and Docker tags on open source repositories"
date: 2023-06-07T12:00:00+01:00
tags: ["docker", "tags", "releases", "open source"]
---

With open source software, it's not an easy task to strike the right balance between producing stable programs and having a decent base of testing users.

This post explains how to best achieve this, and what conclusions resulted from the years I have been developing open source projects.

## Triggers for image tags

- The Git `main` branch (aka `master`) should be your base branch, and commits added to it should trigger a build with the `:latest` tag.
- Pull requests should trigger a build with the `:pr-{pull-request-number}` image tag so that users can easily test the new feature or fix.
- Publishing a Github release should trigger a build with the `:{release-tag}` image tag.
If using semver, this should be the three tags `:vX.Y.Z`, `:vX.Y` and `:vX` so that users can easily pin to a specific version but still get bug fixes or additional features.

## Direct users to use the `:latest` image tag

The foundation of stable software is to have a robust testing suite to avoid relying on users for testing.

However testing cannot cover all cases, especially with a large user base and when the software behaves differently depending on the environment.

For example, with my VPN client Docker image [Gluetun](https://github.com/qdm12/gluetun), there are many aspects that made the software buggy such as the kernel version,
routing, network setup, LXC container runtime etc.

As a consequence, users testing the software in their environment are very valuable and should be encouraged.

This is why I tend to direct users to use the Docker image without a release tag (aka `:latest`) by default.

## Release tags

Even if the general direction for users is to use the latest Docker image, release tags are also available and mentioned.

They should all be as stable as possible, and bug fix releases should be kept low.

The process to do a feature release is the following:

1. 3 weeks after the previous feature release, stop merging/pushing commits to the `main` branch
1. Wait 1 week for users to report issues by testing the `:latest` Docker image.
If any issue is due to a change made since the previous feature release:
    1. Push a fix commit to the `main` branch
    1. Ideally wait 1 week after the last fix commit to make sure no other issue is reported
1. Publish a release targetting the `main` branch

If there is still a somehow critical issue reported after the release is published, a bug fix release can be made:

1. `git checkout <commit-hash>` to the commit hash of the current feature release
1. `git checkout -b vX.Y` to create a new branch `vX.Y` (where the current feature release is `vX.Y.0`)
1. Push a commit to fix the issue to the `vX.Y` branch
1. Publish a release targetting the `vX.Y` branch
1. You can later delete the `vX.Y` branch once the next feature release is published

Release tags are especially useful when the latest Docker image breaks for some users, and they can fallback to a previous release tag.
It's also a nice-to-have to users who don't want to risk using the latest Docker image.
On top of this, it really helps fixing issues reported by users since they would usually try different release tags and mention which ones work and which don't for them.

## Pull requests

Pull requests are a great way to test new features or fixes, and it's important to make it easy for users to test them.

Any pull request should trigger a Docker image build with the `:pr-{pull-request-number}` tag, so users can easily pull and run the image.

One can also restrict this build to be limited to pull requests originating a certain repository, and not forks, to avoid abuse and leaking the Docker image registry credentials.
And then also not trigger from the `dependabot[bot]` user which has not access to the repository secrets.

## Github actions

You must be wondering, how do I do all this on Github!?

The answer is Github actions, and here is a trimmed down example of a workflow file to achieve all this:

```yaml
name: CI
on:
  release:
    types:
      - published
  push:
    branches:
      - main
  pull_request:

jobs:
  publish:
    if: |
      github.repository == 'github_username/github_repository' &&
      (
        github.event_name == 'push' ||
        github.event_name == 'release' ||
        (github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]')
      )
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      # extract metadata (tags, labels) for Docker
      # https://github.com/docker/metadata-action
      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          flavor: |
            latest=${{ github.ref == format('refs/heads/{0}', github.event.repository.default_branch) }}
          images: |
            docker_username/docker_repository
          tags: |
            type=ref,event=pr
            type=semver,pattern=v{{major}}.{{minor}}.{{patch}}
            type=semver,pattern=v{{major}}.{{minor}}
            type=semver,pattern=v{{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
            type=raw,value=latest,enable=${{ github.ref == format('refs/heads/{0}', github.event.repository.default_branch) }}

      - uses: docker/login-action@v2
        with:
          username: docker_username
          password: ${{ secrets.docker_password }}

      - uses: docker/build-push-action@v4
        with:
          tags: ${{ steps.meta.outputs.tags }}
          push: true
```

For production you might want to add more jobs and/or steps, a more concrete example would be [Gluetun's CI workflow file](https://github.com/qdm12/gluetun/blob/943943e8d1818b9c89f8965c4a99f1a72c06b896/.github/workflows/ci.yml).

## Conclusion

I hope this post helped you to better understand how to do Docker image tagging for open source projects.
As a very fast bullet point summary:

- Use the `:latest` tag for the `main` branch
- Use the `:pr-{pull-request-number}` tag for pull requests
- Use the `vX.Y.Z`, `vX.Y` and `vX` tags for releases
- Direct users to the `:latest` tag by default, and mention how to fallback to release tags
