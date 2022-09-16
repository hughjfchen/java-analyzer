{ config, lib, pkgs, ... }: {
  imports = [ ];

  config = {
    api-gw = rec {
      hostName = "a-zdhyw-app05";
      dnsName = "azdhywapp05.cgb.com";
      ipAddress = "21.2.109.74";
      processUser = "jaapiuser";
      isSystemdService = true;
      runDir = "/var/${processUser}/run";
      dataDir = "/var/${processUser}/data";
    };
  };
}
