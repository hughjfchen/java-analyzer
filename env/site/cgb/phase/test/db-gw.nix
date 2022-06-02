{ config, lib, pkgs, ... }:
let envSubM = import ../../../../env.nix { inherit config lib pkgs; };
in {
  imports = [ ];

  options = {
    db-gw = lib.mkOption {
      type = lib.types.submodule envSubM;
      description = ''
        The deploy target host env.
      '';
    };
  };

  config = {
    db-gw = rec {
      hostName = "testdb1";
      dnsName = "testdb1.cgb.com";
      ipAddress = "10.1.23.222";
      processUser = "jadbuser";
      isSystemdService = true;
      configDir = "/var/${processUser}/config";
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
