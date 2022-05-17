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
  my-db-config = (import ../db/release.nix {
    inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget;
  }).my-db-config;

  my-postgrest-config = (import ../db-gw/release.nix {
    inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget
      my-db-config;
  }).my-postgrest-config;

  my-openresty-config = import ./config/${releasePhase}/${releaseHost}/default.nix { pkgs = nPkgs // {inherit my-db-config;} // {inherit my-postgrest-config;}; };

  my-frontend-distributable = import ../frontend/release.nix { pkgs = nPkgs; inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget; };

  # my services dependencies
  # following define the service
  my-openresty-src = nPkgs.stdenv.mkDerivation {
    src = ./.;
    name = "my-openresty-src";
    dontBuild = true;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      cp -R $src/openresty/lua $out/
      cp -R $src/openresty/nginx $out/
      mkdir -p $out/nginx/web
      cp -R ${my-frontend-distributable}/* $out/nginx/web
      mkdir -p $out/lualib
      ln -s $out/lua $out/lualib/user_code
      ln -s $out/lualib $out/nginx/lualib
    '';
  };

  # my services dependencies
  my-openresty-bin-sh = nPkgs.writeShellApplication {
    name = "my-openresty-bin-sh";
    runtimeInputs = [ nPkgs.openresty ];
    text = ''
      [ ! -d /var/log/nginx ] && mkdir -p /var/log/nginx && chown -R ${userName}:${userName} /var/log/nginx
      [ ! -d /var/cache/nginx/client_body ] && mkdir -p /var/cache/nginx/client_body && chown -R ${userName}:${userName} /var/cache/nginx
      [ ! -d /var/${userName}/openresty ] && mkdir -p /var/${userName}/openresty && cp -R ${my-openresty-src}/* /var/${userName}/openresty && chown -R ${userName}:${userName} /var/${userName}/openresty
      [ ! -d /var/${userName}/openresty/nginx/logs ] && mkdir -p /var/${userName}/openresty/nginx/logs && chown -R ${userName}:${userName} /var/${userName}/openresty/nginx/logs
      [ ! -d /var/${userName}/openresty/nginx/web/dumpfiles ] && mkdir -p /var/${userName}/openresty/nginx/web/dumpfiles && chown -R nobody:nogroup /var/${userName}/openresty/nginx/web/dumpfiles
      [ ! -d /var/${userName}/openresty/nginx/web/parsereports ] && mkdir -p /var/${userName}/openresty/nginx/web/parsereports && chown -R nobody:nogroup /var/${userName}/openresty/nginx/web/parsereports
      echo "export DB_HOST=${my-db-config.db.host}" > /var/${userName}/openresty/env.export
      echo "export DB_PORT=${my-db-config.db.port}" >> /var/${userName}/openresty/env.export
      echo "export DB_USER=${my-db-config.db.user}" >> /var/${userName}/openresty/env.export
      echo "export DB_PASS=${my-db-config.db.password}" >> /var/${userName}/openresty/env.export
      echo "export DB_NAME=${my-db-config.db.database}" >> /var/${userName}/openresty/env.export
      echo "export DB_SCHEMA=${my-db-config.db.schema}" >> /var/${userName}/openresty/env.export
      echo "export JWT_SECRET=${my-db-config.db.jwtSecret}" >> /var/${userName}/openresty/env.export
      echo "export POSTGREST_HOST=${my-postgrest-config.postgrest.db-host}" >> /var/${userName}/openresty/env.export
      echo "export POSTGREST_PORT=${my-postgrest-config.postgrest.db-port}" >> /var/${userName}/openresty/env.export
      echo "export OPENRESTY_DOC_ROOT=${my-openresty-config.openresty.docRoot}" >> /var/${userName}/openresty/env.export
      # shellcheck source=/dev/null
      . /var/${userName}/openresty/env.export
      openresty -p "/var/${userName}/openresty/nginx" -c "/var/${userName}/openresty/nginx/conf/nginx.conf" "$@"
    '';
  };

  # following define the service
  my-openresty-service = { lib, pkgs, config, ... }:
    let cfg = config.services.my-openresty;
    in {
      options = {
        services.my-openresty = {
          enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
            description = "enable to generate a config to start the service";
          };
          # add extra options here, if any
        };
      };
      config = lib.mkIf cfg.enable {
        systemd.services.my-openresty = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          description = "my openresty service";
          serviceConfig = {
            Type = "forking";
            ExecStartPre = ''
              ${my-openresty-bin-sh}/bin/my-openresty-bin-sh -t -q -g "daemon on; master_process on;"
            '';
            ExecStart = ''
              ${my-openresty-bin-sh}/bin/my-openresty-bin-sh -g "daemon on; master_process on;"
            '';
            ExecReload = ''
              ${my-openresty-bin-sh}/bin/my-openresty-bin-sh -g "daemon on; master_process on;" -s reload
            '';
            ExecStop = "${my-openresty-bin-sh}/bin/my-openresty-bin-sh -s stop";
            Restart = "on-failure";
          };
        };
      };
    };
  mk-my-openresty-service-unit = nPkgs.writeText "my-openresty.service"
    (nPkgs.nixos ({ lib, pkgs, config, ... }: {
      imports = [ my-openresty-service ];
    })).config.systemd.units."my-openresty.service".text;
in {
  inherit nativePkgs pkgs my-openresty-config;

  mk-my-openresty-service-systemd-setup-or-bin-sh = if genSystemdUnit then
    (nPkgs.setupSystemdUnits {
      namespace = "my-openresty";
      units = { "my-openresty.service" = mk-my-openresty-service-unit; };
    })
  else
    my-openresty-bin-sh;
}
