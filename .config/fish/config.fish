set -gx EDITOR nvim

# Fish plugins come from nixpkgs (see flake.nix), not fisher - that avoids
# piping a bootstrap script into a shell, and keeps plugin files out of this
# repo entirely. Nix drops them under the profile's share/fish/vendor_*.d;
# point fish at those explicitly rather than relying on XDG_DATA_DIRS, which
# is only set for systemd user sessions (see .config/environment.d) and so
# would not apply over SSH or inside a container.
set -l nix_fish ~/.nix-profile/share/fish
set -p fish_function_path $nix_fish/vendor_functions.d
set -p fish_complete_path $nix_fish/vendor_completions.d
if test -d $nix_fish/vendor_conf.d
    for file in $nix_fish/vendor_conf.d/*.fish
        source $file
    end
end

set -g fish_greeting ""

# Catppuccin Mocha, inlined as globals rather than kept as universal
# variables in fish_variables (which fish rewrites at runtime, and which is
# therefore gitignored). There is no catppuccin fish theme in nixpkgs, and
# `fish_config theme` only searches ~/.config/fish/themes anyway, so the
# colours live here directly - no plugin, no fetch, works everywhere.
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

direnv hook fish | source
zoxide init fish --cmd cd | source
if status is-interactive
    # Commands to run in interactive sessions can go here
end
