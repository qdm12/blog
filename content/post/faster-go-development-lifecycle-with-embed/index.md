---
title: "Faster Go development lifecycle with Go 1.16's embed"
description: "How I accelerated my development lifecycle in terms of CI build and Go tooling speeds by using Go 1.16's embed package to bundle bulk data in my binary program"
date: 2021-07-20T15:00:00-06:00
tags: ["go", "compilation", "embed", "gluetun"]
---

This post concerns my most popular Github repository: [github.com/qdm12/gluetun](github.com/qdm12/gluetun).

This is a VPN client application written in Go and meant to be ran in Docker.

Because it is a security and privacy focused application, all VPN servers information including their IP addresses
have to be bundled in the program. This is to avoid using hostnames and leak an initial DNS resolution resolving the VPN server hostname.

Arguably, because gluetun runs in a container, this information could also be stored in the Docker image and read at runtime.
But in my case, I aim at having a statically linked binary that can run without Docker one day... so I wanted this information bundled in the binary.

## Initial implementation

My initial implementation was to hardcode all server information in Go source files.

For example for ProtonVPN servers, they would be hardcoded with:

```go
// ProtonvpnServers returns a slice of all the server information for Protonvpn.
func ProtonvpnServers() []models.ProtonvpnServer {
    return []models.ProtonvpnServer{
        {Country: "Argentina", Region: "", City: "", Name: "CH-AR#1", Hostname: "ch-ar-01a.protonvpn.com", EntryIP: net.IP{185, 159, 157, 114}, ExitIP: net.IP{162, 12, 206, 9}},
        {Country: "Argentina", Region: "", City: "", Name: "SE-AR#1", Hostname: "se-ar-01a.protonvpn.com", EntryIP: net.IP{185, 159, 156, 52}, ExitIP: net.IP{162, 12, 206, 8}},
        {Country: "Argentina", Region: "", City: "Buenos Aires", Name: "AR#1", Hostname: "ar-01.protonvpn.net", EntryIP: net.IP{162, 12, 206, 5}, ExitIP: net.IP{162, 12, 206, 5}},
    // ...
    }
}
```

## Slower compilations

The more I would add VPN service providers to gluetun, the slower everything would be:

- Go compilation
- Linting with `golangci-lint`
- The Go language server `gopls`

That was especially true after adding VPN providers such as NordVPN with thousands of servers.

## Go 1.16's embed

Go 1.16 released in February 2021 and introduced the `embed` standard library package.

> The new embed package provides access to files embedded in the program during compilation using the new `//go:embed` directive.

I have been happily using it for other projects for specific features.
Using it for `gluetun` was more about improving the development lifecyle than adding a feature.

I started by serializing all the servers information in a single JSON file `servers.json` in my `internal/constants` package.

I then added the following code in the `internal/constants` package:

```go
//go:embed servers.json
var allServersEmbedFS embed.FS   //nolint:gochecknoglobals
var allServers models.AllServers //nolint:gochecknoglobals
var parseOnce sync.Once          //nolint:gochecknoglobals

func init() { //nolint:gochecknoinits
    // error returned covered by unit test
    parseOnce.Do(func() { allServers, _ = parseAllServers() })
}

func parseAllServers() (allServers models.AllServers, err error) {
    f, err := allServersEmbedFS.Open("servers.json")
    if err != nil {
        return allServers, err
    }
    decoder := json.NewDecoder(f)
    err = decoder.Decode(&allServers)
    return allServers, err
}

func GetAllServers() models.AllServers {
    parseOnce.Do(func() { allServers, _ = parseAllServers() }) // init did not execute, used in tests
    return allServers
}
```

Note `embed.FS` is used for the single file `servers.json`, instead of a global `[]byte` variable.
This is as such to prevent the servers.json data from being mutated, since `embed.FS` is immutable.

As much as I hate `init()` functions and global variables, I used them for once for multiple reasons:

- I did not want to break the API
- I did not want to have a struct with methods for constant values
- I did not want the JSON unmarshaling of that big 2.5MB JSON file to occur more than once

`parseAllServers` is unit tested to ensure no error is returned from the servers.json data.
Since the servers.json data is constant in the program, we can thus safely ignore the error in the `init()` function.

Finally, we use `sync.Once` so the parsing is only done once and without data races. Notably it prevents the following:

- Parse the data more than once after it has been parsed in the `init()` function
- Data races if `GetAllSevers` is called in parallel

## Results

### Native compilation

We use the following command to measure before and after compilation times:

```sh
time go build -a cmd/gluetun/main.go
```

|  | User | System | CPU | Total |
| --- | --- | --- | --- | --- |
| Before | `47.4s` | `8.5s` | `760%` | `7.3s` |
| After | `27.1s` | `7.9s` | `660%` | `5.3s` |

- time spent in the user space has been reduced by 75%
- time spent in the kernel space has been slightly reduced by ~7%
- 15% less CPU is used
- Total time was reduced by 38%, going down by 2 seconds

### Golangci-lint

We use the following command to measure before and after compilation times:

```sh
time golangci-lint run
```

|  | User | System | CPU | Total |
| --- | --- | --- | --- | --- |
| Before | `2.12s` | `2.33s` | `74%` | `5.94s` |
| After | `1.36s` | `2.36s` | `72%` | `5.12s` |

- time spent in the user space has been reduced by 56%
- time spent in the kernel space did not change
- CPU percentage used did not change
- Total time was reduced by 16%, going down by almost a second

This one second saved looks ridiculous, but since this is ran on every file save, it is much appreciated.

### Gopls

It's harder to measure the performance of gopls, but it definitely feels less laggy especially when navigating the files of my `internal/constants` package.

### Cross architecture builds

Cross architecture builds with Docker running on Github Actions are faster too.

It was taking between 8m30s and 9m30 before, and is now taking consistantly 6m30s.

This 38% speedup, saving about 2m30s, is also much appreciated.

## Conclusion

🐣 Bulk data in Go code is not a good idea

Before `embed` though, this was the only way to bundle data in the binary.

Now thanks to `embed`, immutable data can be incorporated in the binary.

We showed how this improved the development lifecyle speed regarding CI build speed and tooling speed.

So if you are in the same boat as I was, have a go at `embed`! 🎉
