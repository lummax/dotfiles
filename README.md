Dotfiles
===========

These are my dotfiles. `install.sh` installs software and symlinks config
into your `$HOME`, so read it before running it on a machine you care about.

Setup
-----

```
git clone https://github.com/lummax/dotfiles.git && cd dotfiles
./install.sh
```

`install.sh` is idempotent - re-running it picks up new packages and plugins
without redoing the parts that are already in place.

Targets
-------

`install.sh` detects what it is running on and adapts. There is nothing to
pass by hand.

| Target              | Detected by                          | Profile             | Extra stow pass |
| ------------------- | ------------------------------------ | ------------------- | --------------- |
| `darwin`            | `$OSTYPE`                            | `profile`           | `macos/`        |
| `devcontainer`      | `/.dockerenv`, `$REMOTE_CONTAINERS`, `$CODESPACES`, `$DEVCONTAINER` | `profile-container` | - |
| `fedora-silverblue` | `VARIANT_ID=cosmic-atomic`           | `profile`           | `cosmic/`       |
| `fedora`            | `ID=fedora`                          | `profile`           | -               |
| `debian`            | `ID`/`ID_LIKE` of `debian`/`ubuntu`  | `profile-headless`  | -               |

There is no generic Linux fallback - an unrecognised distro is an error
rather than a guess, since the targets differ in package manager and in
whether GUI apps belong there at all.

Packages come from `flake.nix` via
[flakey-profile](https://github.com/lf-/flakey-profile):

- `profile` - desktops (macOS, Fedora). The only profile with GUI apps:
  VS Code and localsend, plus iterm2/yabai/skhd/karabiner on macOS.
- `profile-headless` - ubuntu/debian devboxes. Host tools like tailscale,
  but nothing graphical.
- `profile-container` - devcontainers. Base CLI tools only.

The flake cannot tell which distro it is on (`stdenv.isLinux` is the build
platform), so `install.sh` is what keeps GUI apps off headless boxes, by
picking the profile per target.

Useful by hand:

```
nix run .#profile.switch     # apply
nix run .#profile.rollback   # undo the last switch (does not revert pins)
nix build .#profile          # build without applying
```

### Devcontainers

Nix is installed with `linux --init none` here, because devcontainers
usually do not run systemd and so have no init system to supervise a
daemon. Sandboxing is disabled (`sandbox = false`) since it needs user
namespaces containers commonly restrict. Note that with `--init none` only
root, or a user who can `sudo`, can run nix. The script also skips `chsh`,
fonts and the font cache - set fish as your shell via the image or your
editor's terminal profile instead.

This repo works as a VS Code / Codespaces
[dotfiles repository](https://code.visualstudio.com/docs/devcontainers/containers#_personalizing-with-dotfile-repositories):
point the setting at it and `install.sh` runs automatically. For faster
container startup, bake Nix and the profile into the image rather than
letting every rebuild reinstall them.

### Fedora Silverblue / COSMIC

The base image already ships `git`, `curl` and `fontconfig`, so nothing is
layered with `rpm-ostree` (which would need a reboot). If something is
missing the script says so and stops rather than layering behind your back.

`cosmic/` holds COSMIC desktop config, stowed only on this target. It
deliberately covers just the compositor keyboard layout
(`CosmicComp/xkb_config`) and custom shortcuts
(`CosmicSettings.Shortcuts/custom`, ported from the old yabai/skhd setup).
Theming and wallpaper are **not** tracked, so COSMIC's own settings daemon
stays in charge of them.

Layout
------

Everything at the top level is stowed into `$HOME`, except what
`.stow-local-ignore` excludes - notably `macos/` and `cosmic/`, which are
stowed separately and only on their target.

Plugins are not vendored into this repo:

- fish plugins come from nixpkgs (`fishPlugins.*` in `flake.nix`), not
  fisher. `config.fish` points fish at the profile's `share/fish/vendor_*.d`.
- neovim plugins via `nvim --headless "+Lazy! sync"` in `install.sh`;
  lazy.nvim bootstraps itself.

`fish_variables` is runtime state and is gitignored. Anything worth keeping
lives in `config.fish`, including the Catppuccin Mocha colours.

The only script `install.sh` pipes into a shell is the Determinate Systems
Nix installer, on every target. Everything else comes from a package
manager. `install.sh` never deletes or overwrites existing config: it
simulates each stow pass first and stops with a list if anything would
conflict, leaving you to move those files aside.
