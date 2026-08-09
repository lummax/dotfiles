Dotfiles
========

`install.sh` installs software and symlinks config into `$HOME`. Read it
before running it on a machine you care about.

```
git clone https://github.com/lummax/dotfiles.git && cd dotfiles
./install.sh
```

Re-running is cheap: every step is skipped once it is already done.

Targets
-------

Detected automatically, nothing to pass by hand. An unrecognised distro is
an error rather than a guess.

| Target              | Detected by                         | Profile             | Extra stow |
| ------------------- | ----------------------------------- | ------------------- | ---------- |
| `darwin`            | `$OSTYPE`                           | `profile`           | `macos/`   |
| `devcontainer`      | `/.dockerenv`, `$CODESPACES`, ...   | `profile-container` | -          |
| `fedora-silverblue` | `VARIANT_ID=cosmic-atomic`          | `profile`           | `cosmic/`  |
| `fedora`            | `ID=fedora`                         | `profile`           | -          |
| `debian`            | `ID`/`ID_LIKE` of `debian`/`ubuntu` | `profile-headless`  | -          |

`profile` is the only one with GUI apps; `profile-headless` drops them for
devboxes and `profile-container` is base CLI only. The flake cannot tell
which distro it is on, so `install.sh` picks the profile.

Packages
--------

```
nix run .#profile.switch     # apply
nix run .#profile.rollback   # undo the last switch
nix build .#profile          # build without applying
```

Upgrading is deliberate: `install.sh` only ever installs what is pinned in
`flake.lock` and `.config/nvim/lazy-lock.json`. To move the pins forward,
apply them, and update both lockfiles for review:

```
./upgrade.sh                 # all flake inputs
./upgrade.sh nixpkgs         # just one
```

Notes
-----

- Everything top-level is stowed into `$HOME` except what
  `.stow-local-ignore` excludes. `install.sh` never overwrites existing
  config: it simulates each stow pass and stops with a list of conflicts to
  move aside yourself.
- The Determinate Systems installer is the only script piped into a shell.
- `prek` runs `nixfmt` on commit. `install.sh` installs the hook, since
  `.git/hooks` is not tracked; `prek run --all-files` checks everything by
  hand. The hook is a `local`/`system` one so it uses the `nixfmt` pinned in
  `flake.lock` rather than a second version pinned by `rev` — the cost is
  that it needs the Nix profile on `PATH`, so committing from a GUI client
  that does not source it will fail to find `nixfmt`.
- `cosmic/` tracks only the keyboard layout and custom shortcuts. Theming
  and wallpaper stay with COSMIC's own settings daemon.
- `ssh-agent.service` replaces gnome-keyring's agent on the desktops, which
  cannot sign for the YubiKey's FIDO2 (`sk-*`) keys — it answers "agent
  refused operation". `config.fish` is what points `SSH_AUTH_SOCK` at it,
  and it has to be the shell rather than `environment.d`, because
  gnome-keyring claims the variable at runtime and a value set that late
  wins. Hiding the keyring's autostart entry does not stop it under COSMIC
  either. The unit hangs off `graphical-session.target` rather than
  `default.target` so it starts late enough to have a display to put the
  askpass prompt on. Not installed on devboxes: they are reached over ssh,
  where `config.fish` leaves the forwarded agent alone.
- `~/.ssh/config` is not tracked and deliberately sets no `IdentityFile`:
  naming both YubiKeys costs a PIN prompt and a touch on the wrong one
  before it fails. `ssh-add -K` loads the resident keys off whichever token
  is plugged in, and the agent then offers only that one.
- fish plugins come from nixpkgs, not fisher. `fish_variables` is runtime
  state and is gitignored, so keep anything worth having in `config.fish`.
- Devcontainers install Nix with `--init none` (no systemd), so only root or
  a sudo-capable user can run it; `chsh` and fonts are skipped.
- Fedora Atomic needs `/nix` to exist before the installer runs, which a
  composefs root does not allow. Set `root.transient-ro` in
  `/etc/ostree/prepare-root.conf`, track it with `rpm-ostree initramfs-etc`,
  and add a boot unit that creates `/nix`. See
  [nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445).
