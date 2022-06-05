{ config, lib, pkgs, ... }:
let envSubM = import ../../../../env.nix { inherit config lib pkgs; };
in {
  imports = [ ];

  options = {
    api-gw = lib.mkOption {
      type = lib.types.submodule envSubM;
      description = ''
        The deploy target host env.
      '';
    };
  };

  config = {
    api-gw = rec {
      hostName = "testapi1";
      dnsName = "testapi1";
      ipAddress = "10.1.23.222";
      processUser = "jaapiuser";
      isSystemdService = true;
      configDir = "/var/${processUser}/config";
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
