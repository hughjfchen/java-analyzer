{ config, lib, pkgs, ... }: {
  imports = [ ];

  config = {
    runner = rec {
      hostName = "a-zdhyw-app06";
      dnsName = "21.2.109.74";
      ipAddress = "21.2.109.74";
      processUser = "jarunneruser";
      isSystemdService = false;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
