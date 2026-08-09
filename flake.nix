{
  inputs = {
    flakey-profile.url = "github:lf-/flakey-profile";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      flakey-profile,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # Named rather than a blanket allowUnfree. These are what
          # lib.getName returns, not attribute names: vscode-fhs wraps a
          # buildFHSEnv whose pname is the executable, "code".
          config.allowUnfreePredicate =
            pkg:
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
          # Via nixpkgs, so nothing has to curl a bootstrap script.
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

          python3

          # No `nix` here: the Determinate installer provides it on every
          # target, and this would shadow it with an older nixpkgs build.
          nixfmt
          cacert
        ];

        # Persistent machines (desktop or devbox), not containers.
        hostPackages = with pkgs; [
          tailscale
        ];

        # Desktop targets only, never the headless devbox profile.
        guiPackages = with pkgs; [
          localsend
          # CLI, but it configures a key plugged into this machine, so it
          # belongs with the desktops rather than in basePackages.
          yubikey-manager
          # ssh-agent has no tty to ask for the YubiKey's PIN on, so
          # verify-required keys need an askpass helper. Qt rather than the
          # X11 one: this asks under a Wayland session.
          lxqt.lxqt-openssh-askpass
        ];

        darwinPackages = with pkgs; [
          coreutils
          gnused

          iterm2
          skhd
          yabai
          karabiner-elements
        ];

        # fhs, not plain vscode: this is not NixOS, and the Remote-SSH and
        # Dev Containers extensions ship binaries wanting an FHS layout.
        linuxDesktopPackages = with pkgs; [
          vscode-fhs
        ];
      in
      {
        # Desktops (macOS, Fedora). The only profile with GUI apps.
        packages.profile = flakey-profile.lib.mkProfile {
          inherit pkgs;
          pinned = {
            nixpkgs = toString nixpkgs;
          };
          paths =
            basePackages
            ++ hostPackages
            ++ guiPackages
            ++ lib.optionals pkgs.stdenv.isDarwin darwinPackages
            ++ lib.optionals pkgs.stdenv.isLinux linuxDesktopPackages;
        };

        # ubuntu/debian devboxes: host tools, nothing graphical.
        packages.profile-headless = flakey-profile.lib.mkProfile {
          inherit pkgs;
          pinned = {
            nixpkgs = toString nixpkgs;
          };
          paths = basePackages ++ hostPackages;
        };

        # devcontainers: base CLI only, run daemonless.
        packages.profile-container = flakey-profile.lib.mkProfile {
          inherit pkgs;
          pinned = {
            nixpkgs = toString nixpkgs;
          };
          paths = basePackages;
        };
      }
    );
}
