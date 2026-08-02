#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ID plus ID_LIKE from /etc/os-release, space-padded for substring matching.
# Read in a subshell so the sourced variables do not leak into the script.
os_release_ids() {
    [[ -r /etc/os-release ]] || return 1
    ( . /etc/os-release && echo " ${ID:-} ${ID_LIKE:-} " )
}

detect_target() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo darwin
        return
    fi

    if [[ -f /.dockerenv || -n "${REMOTE_CONTAINERS:-}" || -n "${CODESPACES:-}" || -n "${DEVCONTAINER:-}" ]]; then
        echo devcontainer
        return
    fi

    # Silverblue before plain Fedora: both report ID=fedora, only the
    # atomic COSMIC variant should get the cosmic/ overlay.
    if [[ -r /etc/os-release ]] && grep -q '^VARIANT_ID=cosmic-atomic' /etc/os-release; then
        echo fedora-silverblue
        return
    fi

    local ids
    ids="$(os_release_ids)" || ids=""
    case "$ids" in
    *" fedora "*)
        echo fedora
        return
        ;;
    *" debian "* | *" ubuntu "*)
        echo debian
        return
        ;;
    esac

    # Deliberately no generic Linux fallback: each target differs in
    # package manager and in whether GUI apps belong there, so guessing
    # is worse than saying so.
    echo "Unsupported system (OSTYPE=$OSTYPE, os-release ids:$ids)" >&2
    exit 1
}

bootstrap() {
    local target="$1"
    case "$target" in
    devcontainer | debian)
        # No fontconfig on either: containers have no desktop, and the
        # debian target is a headless devbox whose fonts render on
        # whatever client you SSH in from.
        if command -v apt-get >/dev/null 2>&1; then
            $SUDO apt-get update && $SUDO apt-get install --yes git curl
        fi
        ;;
    fedora-silverblue | fedora)
        # git/curl/fontconfig already ship in the Fedora base images.
        # rpm-ostree layering needs a reboot to take effect, so only reach
        # for it if something is genuinely missing, rather than doing it
        # unconditionally on every run.
        for bin in git curl fc-cache; do
            if ! command -v "$bin" >/dev/null 2>&1; then
                echo "Missing $bin: install it (rpm-ostree install <pkg> + reboot on atomic), then re-run." >&2
                exit 1
            fi
        done
        ;;
    esac
}

install_nix() {
    local target="$1"
    if command -v nix >/dev/null 2>&1; then
        return
    fi

    # The Determinate Systems installer is the only script this repo pipes
    # into a shell. Everything else comes from a package manager.
    local installer=https://install.determinate.systems/nix

    if [[ "$target" == "devcontainer" ]]; then
        # No systemd in most devcontainers, so there is no init system to
        # supervise a daemon: `linux --init none`. Sandboxing needs user
        # namespaces that containers commonly restrict, hence sandbox=false.
        # Caveat: with --init none only root (or users who can sudo) can run
        # nix.
        curl -fsSL "$installer" | sh -s -- install linux \
            --init none \
            --extra-conf "sandbox = false" \
            --determinate \
            --no-confirm
    else
        curl -fsSL "$installer" | sh -s -- install --determinate --no-confirm
    fi

    set +u
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    set -u
}

switch_profile() {
    local target="$1"
    # This is the only place that can decide whether GUI apps belong on a
    # machine: the flake sees the build platform, not the distro, so
    # `profile` would happily install linuxDesktopPackages on a devbox.
    case "$target" in
    devcontainer) nix run .#profile-container.switch ;;
    debian) nix run .#profile-headless.switch ;;
    *) nix run .#profile.switch ;;
    esac
}

setup_shell() {
    local target="$1"
    # No meaningful login shell to change in a container, and often no sudo.
    [[ "$target" == "devcontainer" ]] && return

    local fish_path
    fish_path="$(command -v fish)"
    grep -qxF "$fish_path" /etc/shells || echo "$fish_path" | $SUDO tee -a /etc/shells >/dev/null
    $SUDO chsh -s "$fish_path" "$USER"
}

stow_package() {
    local pkg="$1" simulated
    # Simulate first. stow refuses to overwrite files it does not own, and
    # a half-applied run is worse than none - so report the conflicts and
    # stop rather than touching anything. Never delete a live config file
    # to make room: it may be the only copy, and nothing has replaced it
    # yet at that point.
    if ! simulated="$(stow --target ~/ --no --verbose=1 "$pkg" 2>&1)"; then
        echo "install.sh: stow would conflict for package '$pkg':" >&2
        echo "$simulated" >&2
        echo "Move the listed files aside, then re-run this script." >&2
        exit 1
    fi
    stow --target ~/ "$pkg"
}

stow_dotfiles() {
    local target="$1"
    mkdir -p ~/.config
    stow_package .
    case "$target" in
    darwin) stow_package macos ;;
    fedora-silverblue) stow_package cosmic ;;
    esac
}

setup_nvim() {
    nvim --headless "+Lazy! sync" +qa
}

main() {
    local target
    target="$(detect_target)"
    echo "install.sh: detected target '$target'"

    bootstrap "$target"
    install_nix "$target"
    switch_profile "$target"
    setup_shell "$target"
    stow_dotfiles "$target"
    setup_nvim

    # Rebuild the font cache for the stowed .fonts, on the targets that
    # actually render them locally.
    # NB: keep this an if-statement rather than a `[[ ]] && cmd` one-liner:
    # as the last command in the function the latter returns 1 when the
    # test is false, which `set -e` turns into a spurious failed run.
    if [[ "$target" == "fedora-silverblue" || "$target" == "fedora" ]]; then
        fc-cache -fv
    fi
}

main
