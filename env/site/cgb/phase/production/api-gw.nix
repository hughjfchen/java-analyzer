{ config, lib, pkgs, ... }: {
  imports = [ ];

  config = {
    api-gw = rec {
      hostName = "a-zdhyw-app05";
      dnsName = "21.2.109.75";
      ipAddress = "21.2.109.75";
      processUser = "jaapiuser";
      isSystemdService = true;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
