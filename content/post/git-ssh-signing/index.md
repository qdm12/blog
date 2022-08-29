---
title: "Signing Git commits with SSH and Github"
description: ""
date: 2022-08-27T12:00:00-06:00
tags: ["git", "ssh", "github"]
---

For a very long time, the only way to sign commits that would be compatibly with Github was by using GPG.
Unfortunately, despite GPG being perhaps superior than SSH when it comes to signing, its use is still limited and SSH keys are much more widespread.

In this post, I'll show you how to sign your Git commits with SSH, view signatures in your terminal and configure Github with your key.

## Signing Git commits with SSH

Enter the following commands to configure `git` globally:

```sh
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519
```

where `~/.ssh/id_ed25519` is the path to your ssh private key.

You can now use `git commit -S -m "message"` to sign commits.

For VSCode users, set the configuration `"git.enableCommitSigning": true` so that you can commit through VSCode which will sign your commits.

## Viewing signatures in your terminal

To see commit signatures in your terminal, you need a few adjustments.

Since SSH signing doesn't have a trust chain like GPG, you need to specify pairs of (email, public key) to be trusted.

1. Create a file `~/.ssh/allowed_signers` (path of your choosing)
1. Add your (Git) email address + public key, in my case:

    ```text
    quentin.mcgaw@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII9/8+UQc7dAUIVgldXZH3oFxT0QdF6TWUsHEQPTaYeH quentin@o11
    ```

    You can add more pairs to trust more signers.
1. Configure `git` to use that file:

    ```sh
    git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
    ```

1. Configure `git` to always show signatures in viewing commands such as `git log`:

    ```sh
    git config --global log.showSignature true
    ```

You can now try it out with `git log`, for example I get:

```log
commit 660b85e370c72621529e1986ca67e0219cfbae27 (HEAD -> git-ssh-signing)
Good "git" signature for quentin.mcgaw@gmail.com with ED25519 key SHA256:91Q6hhzy9OpcGGZd0SfLX+vfWUxQ9KLVeUWRRDqvYfE
Author: Quentin McGaw <quentin.mcgaw@gmail.com>
Date:   Sun Aug 28 20:53:00 2022 -0400
```

## Github

Since August 2022, Github supports SSH signing keys and they will show as *verified* on your Github commits.

1. Find your SSH public key. It is usually in `~/.ssh/`, for example `~/.ssh/id_ed25519.pub`.
Mine is `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII9/8+UQc7dAUIVgldXZH3oFxT0QdF6TWUsHEQPTaYeH quentin@o11`
1. Go to [https://github.com/settings/ssh/new](https://github.com/settings/ssh/new) and add your SSH public key as **signing key**

Now your signed commits will show with the *verified* badge!
