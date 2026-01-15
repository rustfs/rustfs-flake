{
  description = "RustFS: High-performance object storage server (Prebuilt Binary Flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      sources = builtins.fromJSON (builtins.readFile ./sources.json);
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Standard NixOS Module
      nixosModules.rustfs = import ./nixos/rustfs.nix;
      nixosModules.default = self.nixosModules.rustfs;

      # Overlays for extending nixpkgs
      overlays.default = final: prev: {
        rustfs = self.packages.${prev.system}.default;
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          srcInfo = sources.files.${system} or (throw "Unsupported system: ${system}");
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "rustfs";
            version = sources.version;

            src = pkgs.fetchurl {
              url = "${sources.downloadBase}/${sources.version}/${srcInfo.name}";
              sha256 = srcInfo.sha256;
            };

            nativeBuildInputs = [ pkgs.unzip ];

            dontUnpack = true;

            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              unzip $src
              if [ ! -f rustfs ]; then
                echo "Error: rustfs binary not found in the archive."
                exit 1
              fi
              install -m755 rustfs $out/bin/rustfs
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "High-performance object storage server written in Rust";
              homepage = "https://rustfs.com";
              license = licenses.asl20;
              platforms = supportedSystems;
              mainProgram = "rustfs";
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ nixpkgs-fmt ];
          };
        }
      );
    };
}
