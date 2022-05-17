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

  # the config
  my-db-config = import ./config/${releasePhase}/${releaseHost}/default.nix { pkgs = nPkgs; lib = lib; config = { inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget;};};
  
  # my services dependencies
  # following define the service
  my-db-init-script = nPkgs.stdenv.mkDerivation {
    src = ./.;
    name = "my-db-init-script";
    dontBuild = true;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp -R $src/sql/libs $out/
      cp -R $src/sql/data $out/
      cp -R $src/sql/api $out/
      cp -R $src/sql/authorization $out/
      cp -R $src/sql/sample_data $out/
      sed "s/\$DB_ANON_ROLE/${my-db-config.db.anonymousRole}/g; s/\$DB_USER/${my-db-config.db.user}/g; s/\$DB_PASS/${my-db-config.db.password}/g; s/\$DB_NAME/${my-db-config.db.database}/g; s/\$JWT_SECRET/${my-db-config.db.jwtSecret}/g" $src/sql/init.sql > $out/init.sql
    '';
  };
  mk-my-postgresql-service-unit = (nPkgs.nixos ({ lib, pkgs, config, ... }: {
    config.services.postgresql = {
      enable = true;
      package = nPkgs.postgresql_9_6;
      port = 5432;
      dataDir = "/var/${userName}/data";
      initdbArgs = [ ];
      initialScript = my-db-init-script + /init.sql;
      ensureDatabases = [ ];
      ensureUsers = [ ];
      enableTCPIP = true;
      authentication = nPkgs.lib.mkOverride 10 ''
        local all all trust
        host all all all md5
      '';
      settings = { };
      #superUser = "postgres"; # read-only

    };
  })).config.systemd.units."postgresql.service".unit;

in {
  inherit nativePkgs pkgs my-db-config;

  mk-my-postgresql-service-systemd-setup-or-bin-sh = if genSystemdUnit then
    (nPkgs.setupSystemdUnits {
      namespace = "my-postgresql";
      units = {
        "my-postgresql.service" = mk-my-postgresql-service-unit
          + /postgresql.service;
      };
    })
  else
    { };
}
