{ nativePkgs ? import ./default.nix { }, # the native package set
pkgs ? import ./cross-build.nix { }
, # the package set for corss build, we're especially interested in the fully static binary
releasePhase, # the phase for release, must be "local", "test" and "production"
releaseHost, # the hostname for release,the binary would deploy to it finally
genSystemdUnit ? true
, # whether should generate a systemd unit and a setup script for the binary
userName ? ""
, # the user name on the target machine. If empty, use the user on the build machine for program directory, root for running program
dockerOnTarget ?
  false # whether docker/docker-compose is needed on the target machine
}:
let
  nPkgs = nativePkgs.pkgs;
  sPkgs = pkgs.x86-musl64; # for the fully static build
  lib = nPkgs.lib; # lib functions from the native package set

  # dependent config
  my-db-config = import ../db/config/${releasePhase}/${releaseHost}/default.nix { pkgs = nPkgs; lib = lib; config = { inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget;};
  };

  # my services dependencies
  # following define the service
  my-postgrest-config = import ./config/${releasePhase}/${releaseHost}/default.nix { pkgs = nPkgs; lib = lib; config = {inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget my-db-config;}; };
  my-postgrest-config-kv = nPkgs.writeTextFile {
    name = "my-postgrest-config";
    # generate the key = value format config, refer to the lib.generators for other formats
    text = (lib.generators.toKeyValue {}) my-postgrest-config.postgrest;
  };

  # my services dependencies
  my-postgrest-bin-sh = nPkgs.writeShellApplication {
    name = "my-postgrest-bin-sh";
    runtimeInputs = [ nPkgs.haskellPackages.postgrest ];
    text = ''
      [ ! -f /var/${userName}/config/postgrest.conf ] && cp ${my-postgrest-config-kv} /var/${userName}/config/postgrest.conf
      postgrest /var/${userName}/config/postgrest.conf "$@"
    '';
  };

  # following define the service
  my-postgrest-service = { lib, pkgs, config, ... }:
    let cfg = config.services.my-postgrest;
    in {
      options = {
        services.my-postgrest = {
          enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
            description = "enable to generate a config to start the service";
          };
          # add extra options here, if any
        };
      };
      config = lib.mkIf cfg.enable {
        systemd.services.my-postgrest = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          description = "my postgrest service";
          serviceConfig = {
            Type = "simple";
            User = "${userName}";
            ExecStart = "${my-postgrest-bin-sh}/bin/my-postgrest-bin-sh";
            Restart = "on-failure";
          };
        };
      };
    };
  mk-my-postgrest-service-unit = nPkgs.writeText "my-postgrest.service"
    (nPkgs.nixos ({ lib, pkgs, config, ... }: {
      imports = [ my-postgrest-service ];
    })).config.systemd.units."my-postgrest.service".text;

in {
  inherit nativePkgs pkgs my-postgrest-config-kv;

  mk-my-postgrest-service-systemd-setup-or-bin-sh = if genSystemdUnit then
    (nPkgs.setupSystemdUnits {
      namespace = "my-postgrest";
      units = { "my-postgrest.service" = mk-my-postgrest-service-unit; };
    })
  else
    my-postgrest-bin-sh;

}
