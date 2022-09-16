{ config, lib, pkgs, ... }: {
  imports = [ ];

  config = {
    db-gw = rec {
      hostName = "a-zdhyw-db01";
      dnsName = "21.2.109.73";
      ipAddress = "21.2.109.73";
      processUser = "jadbgwuser";
      isSystemdService = true;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
