set -gx EDITOR nvim

# Plugins come from nixpkgs, not fisher. Point fish at the profile's vendor
# dirs explicitly: XDG_DATA_DIRS is only set for systemd user sessions, so it
# would not cover SSH or containers.
set -l nix_fish ~/.nix-profile/share/fish
set -p fish_function_path $nix_fish/vendor_functions.d
set -p fish_complete_path $nix_fish/vendor_completions.d
if test -d $nix_fish/vendor_conf.d
    for file in $nix_fish/vendor_conf.d/*.fish
        source $file
    end
end

set -g fish_greeting ""

# Catppuccin Mocha as globals: fish_variables is runtime state and gitignored,
# and there is no catppuccin fish theme in nixpkgs.
set -g fish_color_autosuggestion 6c7086
set -g fish_color_cancel f38ba8
set -g fish_color_command 89b4fa
set -g fish_color_comment 7f849c
set -g fish_color_cwd f9e2af
set -g fish_color_cwd_root red
set -g fish_color_end fab387
set -g fish_color_error f38ba8
set -g fish_color_escape eba0ac
set -g fish_color_gray 6c7086
set -g fish_color_history_current --bold
set -g fish_color_host 89b4fa
set -g fish_color_host_remote a6e3a1
set -g fish_color_keyword f38ba8
set -g fish_color_normal cdd6f4
set -g fish_color_operator f5c2e7
set -g fish_color_option a6e3a1
set -g fish_color_param f2cdcd
set -g fish_color_quote a6e3a1
set -g fish_color_redirection f5c2e7
set -g fish_color_search_match --background=313244
set -g fish_color_selection --background=313244
set -g fish_color_status f38ba8
set -g fish_color_user 94e2d5
set -g fish_color_valid_path --underline
set -g fish_pager_color_completion cdd6f4
set -g fish_pager_color_description 6c7086
set -g fish_pager_color_prefix f5c2e7
set -g fish_pager_color_progress 6c7086

fish_add_path ~/.local/bin/
fish_add_path ~/.nix-profile/bin/
# nix lives in the default profile; its /etc/profile.d snippet is POSIX-only,
# so fish never sees it. Appended, so ~/.nix-profile keeps priority.
fish_add_path --append /nix/var/nix/profiles/default/bin
set -gx NIX_PROFILES "/nix/var/nix/profiles/default $HOME/.nix-profile"

# Point at ssh-agent.service. Here rather than in environment.d, because
# gnome-keyring claims SSH_AUTH_SOCK at runtime and a value set that late
# outranks environment.d - and its agent cannot sign for the YubiKey's FIDO2
# (sk-*) keys. Guarded twice: no socket means no agent of ours to point at,
# and SSH_CONNECTION means this shell is on the far end of a forwarded agent
# that should be left alone.
if test -S $XDG_RUNTIME_DIR/ssh-agent.socket; and not set -q SSH_CONNECTION
    set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket
end

direnv hook fish | source
zoxide init fish --cmd cd | source
if status is-interactive
    # Commands to run in interactive sessions can go here
end
