{
  inputs = {
    flakey-profile.url = "github:lf-/flakey-profile";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, flakey-profile }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # vscode is unfree. Allow it by name rather than setting
          # allowUnfree globally, so nothing else slips in unnoticed.
          #
          # The names are what `lib.getName` returns, not the attribute
          # names: vscode-fhs wraps the editor in a buildFHSEnv whose pname
          # is the *executable* name, "code" (see vscode/generic.nix), and
          # "vscode" is the unwrapped derivation inside it.
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [
              "code"
              "vscode"
            ];
        };
        lib = pkgs.lib;

        # CLI tools wanted everywhere, including ephemeral devcontainers.
        basePackages = with pkgs; [
          tree
          moreutils
          util-linux

          curl
          fish
          # Fish plugins via nixpkgs instead of fisher, so install.sh does
          # not have to curl a bootstrap script into a shell.
          fishPlugins.bass
          stow

          git
          git-absorb
          git-lfs

          bat
          direnv
          fzf
          neovim
          ripgrep
          zoxide

          bazelisk
          commitizen
          hyperfine
          prek
          timewarrior

          python3.10

          nix
          nixfmt
          cacert
        ];

        # Tools for a persistent machine - desktop or devbox - but not for
        # an ephemeral container.
        hostPackages = with pkgs; [
          tailscale
        ];

        # Cross-platform GUI apps. These reach desktop targets only, never
        # the headless devbox profile.
        guiPackages = with pkgs; [
          localsend
        ];

        darwinPackages = with pkgs; [
          coreutils
          gnused

          iterm2
          skhd
          yabai
          karabiner-elements
        ];

        # GUI apps for Linux desktops (Silverblue/COSMIC), installed via Nix
        # instead of Flatpak so they pick up .nix-profile/share via
        # .config/environment.d/10-xdg-data-dir.conf.
        #
        # vscode-fhs rather than plain vscode: this is not NixOS, and the
        # Remote-SSH / Dev Containers extensions download their own
        # prebuilt binaries, which expect a standard FHS layout and
        # dynamic loader. The FHS wrapper provides that.
        linuxDesktopPackages = with pkgs; [
          vscode-fhs
        ];
      in {
        # Any extra arguments to mkProfile are forwarded directly to pkgs.buildEnv.
        #
        # Usage:
        # Switch to this flake:
        #   nix run .#profile.switch
        # Revert a profile change (note: does not revert pins):
        #   nix run .#profile.rollback
        # Build, without switching:
        #   nix build .#profile
        # Pin nixpkgs in the flake registry and in NIX_PATH, so that
        # `nix run nixpkgs#hello` and `nix-shell -p hello --run hello` will
        # resolve to the same hello as below [should probably be run as root, see README caveats]:
        #   sudo nix run .#profile.pin
        # Desktop profile: macOS and Fedora (incl. Silverblue). The only
        # profile carrying GUI apps. Nothing here can tell which distro it
        # is running on - stdenv.isLinux is the build platform - so it is
        # install.sh that keeps this off headless machines by selecting
        # profile-headless instead.
        packages.profile = flakey-profile.lib.mkProfile {
          inherit pkgs;
          # Specifies things to pin in the flake registry and in NIX_PATH.
          pinned = { nixpkgs = toString nixpkgs; };
          paths = basePackages ++ hostPackages ++ guiPackages
            ++ lib.optionals pkgs.stdenv.isDarwin darwinPackages
            ++ lib.optionals pkgs.stdenv.isLinux linuxDesktopPackages;
        };

        # Headless profile for ubuntu/debian devboxes: a persistent machine,
        # so it gets the host tools, but no GUI apps to download and never
        # run.
        packages.profile-headless = flakey-profile.lib.mkProfile {
          inherit pkgs;
          pinned = { nixpkgs = toString nixpkgs; };
          paths = basePackages ++ hostPackages;
        };

        # Minimal/fast profile for devcontainers: base CLI tools only, no
        # host or GUI packages. Meant to be run daemonless - see install.sh.
        packages.profile-container = flakey-profile.lib.mkProfile {
          inherit pkgs;
          pinned = { nixpkgs = toString nixpkgs; };
          paths = basePackages;
        };
      });
}
