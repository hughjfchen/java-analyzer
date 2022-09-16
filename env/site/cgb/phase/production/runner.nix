{ config, lib, pkgs, ... }: {
  imports = [ ];

  config = {
    runner = rec {
      hostName = "a-zdhyw-app05";
      dnsName = "21.2.109.75";
      ipAddress = "21.2.109.75";
      processUser = "jarunneruser";
      isSystemdService = false;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
