# Example NixOS configuration module for RustFS
#
# This file can be imported into your main configuration.nix

{ config, pkgs, ... }:

{
  services.rustfs = {
    enable = true;
    
    # Storage path
    volumes = "/var/lib/rustfs/data";
    
    # API server address (Port 9000)
    address = "127.0.0.1:9000";

    # Management console configuration (Port 9001)
    consoleEnable = true;
    consoleAddress = "127.0.0.1:9001";

    # Logging configuration
    logLevel = "info";
    logDirectory = "/var/log/rustfs";

    # Security: In production, use sops-nix or agenix to inject these
    accessKey = "rustfs-admin";
    secretKey = "change-me-in-production";
  };

  # Open firewall ports for both API and Console
  networking.firewall.allowedTCPPorts = [
    9000 # RustFS API
    9001 # RustFS Console
  ];
}
