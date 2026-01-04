# Example NixOS configuration for running RustFS
#
# This example shows how to set up RustFS as a systemd service on NixOS.
# Add this to your /etc/nixos/configuration.nix or as a separate module.

{ config, pkgs, ... }:

{
  imports = [
    # Import the RustFS flake module
    # You can reference this via flake inputs in your system flake.nix
  ];

  # Enable the RustFS service
  services.rustfs = {
    enable = true;
    
    # Data directory - where RustFS stores objects
    dataDir = "/var/lib/rustfs/data";
    
    # API server address - accessible from network
    # Use "0.0.0.0:9000" to listen on all interfaces
    address = "0.0.0.0:9000";
    
    # Console web UI address
    consoleAddress = "0.0.0.0:9001";
    
    # Optional: Path to configuration file
    # configFile = "/etc/rustfs/config.yaml";
    
    # Optional: Additional command-line arguments
    # extraArgs = [ "--debug" ];
  };

  # Open firewall ports for RustFS
  networking.firewall = {
    allowedTCPPorts = [
      9000  # RustFS API
      9001  # RustFS Console
    ];
  };

  # Optional: Create admin users with access to RustFS data
  # users.users.rustfs-admin = {
  #   isNormalUser = true;
  #   extraGroups = [ "rustfs" ];
  # };
}
