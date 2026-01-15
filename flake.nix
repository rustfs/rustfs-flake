{
  description = "rustfs prebuilt binary flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      rustfsSrc =
        system:
        let
          file = sources.files.${system} or (throw "Unsupported system: ${system}");
        in
        {
          url = "${sources.downloadBase}/${sources.version}/${file.name}";
          sha256 = file.sha256;
        };

    in
    {
      nixosModules.rustfs = import ./nixos/rustfs.nix;
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          srcInfo = rustfsSrc system;
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "rustfs";
            version = sources.version;

            src = pkgs.fetchurl {
              inherit (srcInfo) url sha256;
            };

            nativeBuildInputs = [ pkgs.unzip ];

            dontUnpack = true;

            installPhase = ''
              mkdir -p $out/bin
              unzip $src
              if [ ! -f rustfs ]; then
                echo "Error: rustfs binary not found in the archive."
                exit 1
              fi
              install -m755 rustfs $out/bin/rustfs
            '';
          };
        }
      );
    };
}