---
title: "Alpine: why wget and not curl?"
description: "Have you ever wondered why Alpine comes with wget and not curl?"
date: 2021-06-25T11:00:00-06:00
tags: ["docker", "dockerfile", "cross cpu", "go", "buildkit", "vscode"]
---

Alpine is **tiny**. The `alpine:3.14` Docker image is only **5.6MB** uncompressed on `amd64`.

Alpine achieves this partly thanks to [busybox](https://busybox.net/), which Docker image `busybox` is only **1.24MB**.

Alpine comes with `wget` implemented in its Busybox multi-call binary.

You can try it with:

```sh
docker run -it --rm busybox wget
```

But why isn't `curl` implemented as well, or instead of `wget`?? 🤔

## `wget` vs `curl`

The following table shows some key differences between the two, comparing the two installs on Alpine by using

```sh
docker run -it --rm alpine:3.14
apk add wget
apk add curl
```

| | `wget` | `curl` |
| --- | --- | --- |
| Binary size | `445KB` | `230KB` |
| Size with dependencies | `2MB` | `2MB` |
| Dependencies | `libunistring`, `libidn2` | `brotli-libs`, `nghttp2-libs`, `libcurl` |
| License | `GPL v3` | `MIT` |
| Recursive downloading | yes | no |
| HTTP(S) | `GET`, `POST` and `CONNECT` requests only | yes |
| FTP(S) | yes | yes |
| GOPHER(S) | no | yes |
| HTTP(S) | no | yes |
| SCP | no | yes |
| SFTP | no | yes |
| TFTP | no | yes |
| TELNET | no | yes |
| DICT | no | yes |
| LDAP(S) | no | yes |
| MQTT | no | yes |
| FILE | no | yes |
| POP3(S) | no | yes |
| IMAP(S) | no | yes |
| SMB(S) | no | yes |
| SMTP(S) | no | yes |
| RTMP | no | yes |
| RTSP | no | yes |
| SOCKS | no | yes |

All developers know of `curl` and love it.

Given the limited abilities of `wget`, not many developers know about it.

## Why not `curl`?

### Size

From a first look, the binary size and dependencies size of the `wget` and `curl` Alpine packages are about 2MB.
So that does not look to be a size issue.

Now, `busybox` implements the code for wget so it's all bundled in a single static binary.

> BusyBox combines tiny versions of many common UNIX utilities into a single small executable. ([source](https://busybox.net/about.html))

The size of `busybox` being about `1MB`, it clearly shows it's a trimmed down version of `wget`, especially since `busybox` can do plenty of other things too.

You can also see that:

```sh
docker run -it --rm alpine:3.14 wget --help
```

and

```sh
docker run -it --rm alpine:3.14 apk add wget && wget --help
```

result in quite different help messages, where the second one is a lot more *complete*.

This is because `busybox` implements the bare minimum to have `wget` working, it's not the complete `wget` you get with the Alpine package manager.

> The utilities in BusyBox generally have fewer options than their full-featured GNU cousins; however, the options that are included provide the expected functionality and behave very much like their GNU counterparts. ([source](https://busybox.net/about.html))

Supporting all the features of `curl` would result in a much larger multi-call binary. Probably only 1MB extra, but this would still be a 100% increase in size!

### Complexity to implement

`curl` has so many features it is harder to implement and maintain it as part of the busybox multi-call binary.

### Security

There may also be a security aspect to it, since `curl` offers so many protocols and features, it is a harder piece to keep secured than `wget`.

EDIT (2021-07-02): It turns out that, as [@tianon](https://github.com/tianon) very well says it:

> I mean, yes, but also very much no: [#80](https://github.com/docker-library/busybox/issues/80) (TLS validation is Broken-By-Design)

🤯🤯🤯🤯🤯
