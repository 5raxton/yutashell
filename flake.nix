{
  description = "yutashell — quickshell config for Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell = {
      url = "github:outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , quickshell
    , home-manager
    }: let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [quickshell.overlays.default];
      };
    in {
      # the config itself, as a versioned store path
      packages.${system}.default = pkgs.stdenvNoCC.mkDerivation {
        pname = "yutashell";
        version = "0.1.0";
        src = self;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/share/yutashell
          cp -r . $out/share/yutashell/
        '';
      };

      homeManagerModules.yutashell = {
        config,
        lib,
        pkgs,
        ...
      }: let
        cfg = config.programs.yutashell;
      in {
        options.programs.yutashell = {
          enable = lib.mkEnableOption "yutashell quickshell config";
          package = lib.mkOption {
            type = lib.types.package;
            default = quickshell.packages.${pkgs.system}.default;
          };
        };

        config = lib.mkIf cfg.enable {
          # runtime deps the shell assumes (see scripts/install.sh)
          home.packages = with pkgs;
              [
                cfg.package
                matugen
                grim
                slurp
                curl
              ]
            ++ lib.optionals config.wayland.windowManager.hyprland.enable [
              cava
            ];

          xdg.configFile."quickshell/yuta-qs".source = self;

          wayland.windowManager.hyprland.settings.exec-once =
            lib.mkAfter ["qs -c yuta-qs"];
        };
      };
    };
}
