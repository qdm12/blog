---
title: "Nushell: install plugins faster"
description: "Nushell is awesome, but installing plugins...not so great...let's make it great!"
date: 2024-01-17T10:00:00+01:00
tags: ["nushell", "cargo", "shell"]
---

[Nushell](https://www.nushell.sh/) is a pretty cool project written in [Rust](https://www.rust-lang.org/) to have a shell working the same on all platforms.
It can notably be extended with [plugins](https://www.nushell.sh/book/plugins.html).
But figuring out how to install them from [their instructions](https://www.nushell.sh/book/plugins.html#adding-a-plugin) and, even after this, the many steps required, ruined my excitement.
Here's how I made it exciting again! 🚀

### Install once

1. Install [Rust](https://www.rust-lang.org/), [GCC](https://gcc.gnu.org/) and [Git](https://git-scm.com/). There are [detailed steps below](#install-rust-gcc-and-git) for [Windows](#windows), [OSX](#osx) and [Linux](#linux) if you need to install any.
1. Launch a Nushell terminal
1. Setup a custom command `install_plugin` in your Nushell configuration:

    ```sh
    echo "
    def install_plugin [plugin_name: string, git_repository_url?: string, git_tag?: string] {
        mut cargo_install_flags = {}

        # Git repository URL defaults to Nushell repository.
        if ($git_repository_url == null) {
            $cargo_install_flags = ($cargo_install_flags | insert "--git" "https://github.com/nushell/nushell.git")
        } else {
            $cargo_install_flags = ($cargo_install_flags | insert "--git" $git_repository_url)
        }

        # If the repository URL is the Nushell repository, the tag defaults to
        # the current Nushell version.
        if $git_tag != null and $git_tag != "" {
            $cargo_install_flags = ($cargo_install_flags | insert "--tag" $git_tag)
        } else if ($cargo_install_flags | get "--git") == "https://github.com/nushell/nushell.git" {
            $cargo_install_flags = ($cargo_install_flags | insert "--tag" (version | get version))
        }

        let flags = ($cargo_install_flags | items {|key, value| echo $'($key) ($value)' } | str join " ")
        nu -c $"cargo install ($flags) nu_plugin_($plugin_name)";

        const home_directory = ("~" | path expand)
        let cargo_bin_directory = $"($home_directory)/.cargo/bin"
        mut plugin_path = $"($cargo_bin_directory)/nu_plugin_($plugin_name)"
        if (sys).host.name == "Windows" {
            $plugin_path += ".exe"
        }
        nu -c $"register ($plugin_path)"
    }
    " | save $nu.config-path --append
    ```

1. Reload the configuration file with

    ```sh
    source $nu.config-path
    ```

### Installing a plugin

1. Find which plugin you want from [awesome-nu#plugins](https://github.com/nushell/awesome-nu#plugins). Let's say `nu_plugin_gstat` for example.
1. In a Nushell terminal, you can use the `install_plugin` custom command:

    ```sh
    Usage:
      > install_plugin <plugin_name> (git_repository_url) (git_tag)

    Flags:
      -h, --help - Display the help message for this command

    Parameters:
      plugin_name <string>:
      git_repository_url <string>:  (optional)
      git_tag <string>:  (optional)
    ```

1. For plugins:
    - from the Nushell repository, run `install_plugin plugin_name`, for example `install_plugin gstat`
    - For plugins on other repositories, run `install_plugin plugin_name git_repository_url (git_tag)`, for example
    `install_plugin qr_maker https://github.com/FMotalleb/nu_plugin_qr_maker.git`

*What steps did we save here?* 🕥

- Cloning or downloading manually repositories hosting plugins
- Keeping the Nushell repository locally in sync with the release of Nushell you are running
- Running one command to build the plugin and one to register it
- Saving the repetitive keystrokes to write the plugin prefix `nu_plugin_` in its name 😉

### Further improvements

1. The second custom command line `nu -c $'register ~/.cargo/bin/($plugin_name).exe'` is a bit obscure,
since running directly `register $'~/.cargo/bin/($plugin_name).exe'` gives the error `Value is not a parse-time constant`.
It would be nice to allow variable names, since anyway it's feasible using `nu -c`.
I created issue [#11556](https://github.com/nushell/nushell/issues/11556) to track this.

### Install Rust, GCC and Git

The following describes how to install the required tools to install Nushell plugins for [Windows](#windows), [OSX](#osx) and [Linux](#linux).

#### Windows

1. Ensure you have the [Microsoft Winget](https://github.com/microsoft/winget-cli) installed.
You can install it with the [Microsoft Store](https://www.microsoft.com/store/productId/9NBLGGH4NNS1?ocid=pdpshare) or by [downloading the Winget installer](https://aka.ms/getwinget) or with this Powershell code:

    ```powershell
    $URL = (Invoke-WebRequest -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest").Content |
        ConvertFrom-Json | Select-Object -ExpandProperty "assets" |
        Where-Object "browser_download_url" -Match '.msixbundle' |
        Select-Object -ExpandProperty "browser_download_url"
    Invoke-WebRequest -Uri $URL -OutFile "Setup.msix" -UseBasicParsing
    Add-AppxPackage -Path "Setup.msix"
    Remove-Item "Setup.msix"
    ```

1. Ensure you have [Chocolatey](https://chocolatey.org/) installed, you can install it with:

    ```powershell
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
      Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
    ```

    Chocolatey is required for now to install MinGW which winget [doesn't support yet](https://github.com/microsoft/winget-pkgs/issues/122962).

1. Install [Rust](https://www.rust-lang.org/), [MinGW](https://www.mingw-w64.org/) and [Git](https://git-scm.com/) with this Powershell code:

    ```powershell
    winget install Rustlang.Rust.GNU Cygwin.Cygwin Git.Git
    if ($env:USERNAME -eq 'SYSTEM') {
      choco install -y mingw
    } else {
      Start-Process -FilePath "choco.exe" -ArgumentList "install -y mingw" -Verb RunAs -Wait
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    ```

#### OSX

1. Ensure you have [brew](https://brew.sh/) installed, you can install it with:

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

1. Install [Rust](https://www.rust-lang.org/), [GCC](https://gcc.gnu.org/) and [Git](https://git-scm.com/) with:

    ```bash
    brew install rust gcc git
    ```

#### Linux

- Ubuntu: `sudo apt install -y rustc gcc git`
- Fedora: `sudo dnf install -y rust gcc git`
- Arch: `sudo pacman -Sy rust gcc git`
- Alpine: `sudo apk add rust gcc git`
