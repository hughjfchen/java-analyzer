{ config, lib, pkgs, ... }: {
  imports = [ ];

  config = {
    messaging = rec {
      hostName = "a-zdhyw-db01";
      dnsName = "21.2.109.73";
      ipAddress = "21.2.109.73";
      processUser = "jamsguser";
      isSystemdService = true;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
