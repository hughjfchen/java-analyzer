{ config, lib, pkgs, ... }: {
  imports = [ ];

  config = {
    db = rec {
      hostName = "a-zdhyw-db01";
      dnsName = "21.2.109.73";
      ipAddress = "21.2.109.73";
      processUser = "jadbuser";
      isSystemdService = true;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
