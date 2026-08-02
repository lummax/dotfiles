#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Space-padded so the case arms below can match whole words.
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

    # Before plain fedora: both report ID=fedora.
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

    echo "Unsupported system (OSTYPE=$OSTYPE, os-release ids:$ids)" >&2
    exit 1
}

bootstrap() {
    local target="$1"
    case "$target" in
    devcontainer | debian)
        if command -v apt-get >/dev/null 2>&1; then
            $SUDO apt-get update && $SUDO apt-get install --yes git curl
        fi
        ;;
    fedora-silverblue | fedora)
        # Layering would need a reboot, so ask rather than do it.
        for bin in git curl fc-cache; do
            if ! command -v "$bin" >/dev/null 2>&1; then
                echo "Missing $bin: install it (rpm-ostree install <pkg> + reboot on atomic), then re-run." >&2
                exit 1
            fi
        done
        ;;
    esac
}

NIX_PROFILE_SCRIPT=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

load_nix() {
    [[ -r "$NIX_PROFILE_SCRIPT" ]] || return 0
    set +u
    # shellcheck disable=SC1090
    . "$NIX_PROFILE_SCRIPT"
    set -u
}

install_nix() {
    local target="$1"

    # Load first: this is a non-login shell, so /etc/profile.d is never
    # sourced and an existing nix would look absent and be reinstalled.
    load_nix
    if command -v nix >/dev/null 2>&1; then
        return
    fi

    local installer=https://install.determinate.systems/nix

    if [[ "$target" == "devcontainer" ]]; then
        # No systemd to supervise a daemon, and sandboxing needs user
        # namespaces containers restrict. Only root can run nix afterwards.
        curl -fsSL "$installer" | sh -s -- install linux \
            --init none \
            --extra-conf "sandbox = false" \
            --determinate \
            --no-confirm
    else
        curl -fsSL "$installer" | sh -s -- install --determinate --no-confirm
    fi

    load_nix
}

# The flake sees the build platform, not the distro, so this is the only
# place that can keep GUI apps off headless machines.
switch_profile() {
    local target="$1"
    case "$target" in
    devcontainer) nix run .#profile-container.switch ;;
    debian) nix run .#profile-headless.switch ;;
    *) nix run .#profile.switch ;;
    esac
}

setup_shell() {
    local target="$1"
    if [[ "$target" == "devcontainer" ]]; then
        return
    fi

    local fish_path
    fish_path="$(command -v fish)"
    grep -qxF "$fish_path" /etc/shells || echo "$fish_path" | $SUDO tee -a /etc/shells >/dev/null

    if [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$fish_path" ]]; then
        return
    fi
    $SUDO chsh -s "$fish_path" "$USER"
}

stow_package() {
    local pkg="$1" simulated
    # A half-applied run is worse than none, and a live config file may be
    # the only copy.
    if ! simulated="$(stow --target ~/ --no --verbose=1 "$pkg" 2>&1)"; then
        echo "install.sh: stow would conflict for package '$pkg':" >&2
        echo "$simulated" >&2
        echo "Move the listed files aside, then re-run this script." >&2
        exit 1
    fi
    stow --target ~/ "$pkg"
}

# COSMIC saves settings atomically (temp file + rename), which replaces a
# per-file symlink rather than writing through it - the change then lands
# outside this repo, silently. Folding ~/.config/cosmic into one directory
# symlink keeps those writes inside the repo, where they show up as a diff.
#
# Stow only folds when nothing exists at the target, but COSMIC recreates
# empty component directories on login, so clear them first. Only ever when
# they hold no regular files, and by rename, since COSMIC races a recursive
# delete by recreating directories underneath it.
fold_cosmic_dir() {
    local dir=~/.config/cosmic
    [[ -d "$dir" && ! -L "$dir" ]] || return 0
    [[ -z "$(find "$dir" -type f -print -quit 2>/dev/null)" ]] || return 0

    local aside="$dir.pre-stow.$$"
    mv "$dir" "$aside" && rm -rf "$aside"
}

stow_dotfiles() {
    local target="$1"
    mkdir -p ~/.config
    stow_package .
    case "$target" in
    darwin) stow_package macos ;;
    fedora-silverblue)
        fold_cosmic_dir
        stow_package cosmic
        ;;
    esac
}

setup_nvim() {
    # Bootstrap only; upgrade.sh updates them.
    local lazy_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
    if [[ -d "$lazy_dir" ]] && [[ -n "$(ls -A "$lazy_dir" 2>/dev/null)" ]]; then
        return
    fi
    # restore, not sync: the versions pinned in lazy-lock.json.
    nvim --headless "+Lazy! restore" +qa
}

# The themes settings.json names are contributed by extensions, so without
# these VS Code silently falls back to its defaults.
setup_vscode() {
    command -v code >/dev/null 2>&1 || return 0

    local installed
    installed="$(code --list-extensions 2>/dev/null)" || return 0

    local ext
    for ext in Catppuccin.catppuccin-vsc Catppuccin.catppuccin-vsc-icons; do
        grep -qix -- "$ext" <<<"$installed" || code --install-extension "$ext"
    done
}

# .git/hooks is not tracked, so a fresh clone has no hooks until this runs.
# prek comes from the profile, so this has to follow switch_profile.
setup_git_hooks() {
    command -v prek >/dev/null 2>&1 || return 0

    # --git-path, not .git/hooks: fails cleanly when this is a tarball
    # rather than a clone, and resolves worktrees, where .git is a file.
    local hook
    hook="$(git rev-parse --git-path hooks/pre-commit 2>/dev/null)" || return 0

    if [[ -f "$hook" ]] && grep -q 'generated by prek' "$hook"; then
        return 0
    fi
    prek install
}

setup_fonts() {
    local target="$1"
    case "$target" in
    fedora-silverblue | fedora) ;;
    *) return ;;
    esac

    if fc-list 2>/dev/null | grep -qi jetbrainsmono; then
        return
    fi
    fc-cache -f
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
    setup_vscode
    setup_fonts "$target"
    setup_git_hooks
}

# Only run when executed; upgrade.sh sources this for the helpers.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
