{
  description = "Example NixOS system using RustFS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rustfs-flake.url = "path:../.";
  };

  outputs = { self, nixpkgs, rustfs-flake }: {
    nixosConfigurations.example-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        rustfs-flake.nixosModules.default
        
        ({ config, pkgs, ... }: {
          services.rustfs = {
            enable = true;
            package = rustfs-flake.packages.${pkgs.system}.default;

            volumes = "/var/lib/rustfs/data";

            # API Service on 9000
            address = "0.0.0.0:9000";

            # Console Service on 9001
            consoleEnable = true;
            consoleAddress = "0.0.0.0:9001";

            accessKey = "admin-access-key";
            secretKey = "secure-secret-key";

            logLevel = "info";
          };

          # Open both API and Console ports in firewall
          networking.firewall.allowedTCPPorts = [ 9000 9001 ];

          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
