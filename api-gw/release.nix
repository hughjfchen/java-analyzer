{ nativePkgs ? import ./default.nix { }, # the native package set
pkgs ? import ./cross-build.nix { }
, # the package set for corss build, we're especially interested in the fully static binary
site , # the site for release, the binary would deploy to it finally
phase, # the phase for release, must be "local", "test" and "production"
}:
let
  nPkgs = nativePkgs.pkgs;
  sPkgs = pkgs.x86-musl64; # for the fully static build
  lib = nPkgs.lib; # lib functions from the native package set
  pkgName = "my-openresty";
  innerTarballName = lib.concatStringsSep "." [ (lib.concatStringsSep "-" [ pkgName site phase ]) "tar" "gz" ];

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  release-utils = import ./release-utils.nix { inherit lib; pkgs = nPkgs; };

  # the deployment env
  my-openresty-env = (import ../env/site/${site}/phase/${phase}/env.nix { pkgs = nPkgs; }).env;

  # dependent config
  my-openresty-config = (import ../config/site/${site}/phase/${phase}/config.nix { pkgs = nPkgs; env = my-openresty-env; }).config;

  # the frontend, comment out for now.
  #my-frontend-distributable = (import ../frontend/release.nix { pkgs = nPkgs; inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget; }).my-frontend-distributable;

  # my services dependencies
  # following define the service
  my-openresty-src = nPkgs.stdenv.mkDerivation {
    src = ./.;
    name = lib.concatStringsSep "-" [ pkgName "src" ];
    dontBuild = true;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out
      mkdir -p $out/lua
      mkdir -p $out/nginx
      mkdir -p $out/nginx/conf
      mkdir -p $out/nginx/web
      mkdir -p $out/lualib
      cp -R $src/openresty/lua/* $out/lua/
      cp -R $src/openresty/nginx/conf/* $out/nginx/conf/
      ln -s $out/lua $out/lualib/user_code
      ln -s $out/lualib $out/nginx/lualib
    '';
  };

  # my services dependencies
  my-openresty-bin-sh = nPkgs.writeShellApplication {
    name = lib.concatStringsSep "-" [ pkgName "bin" "sh" ];
    runtimeInputs = [ nPkgs.openresty ];
    text = ''
      [ ! -d /var/log/nginx ] && mkdir -p /var/log/nginx && chown -R ${my-openresty-env.api-gw.processUser}:${my-openresty-env.api-gw.processUser} /var/log/nginx
      [ ! -d /var/cache/nginx/client_body ] && mkdir -p /var/cache/nginx/client_body && chown -R ${my-openresty-env.api-gw.processUser}:${my-openresty-env.api-gw.processUser} /var/cache/nginx
      [ ! -d /var/${my-openresty-env.api-gw.processUser}/openresty ] && mkdir -p /var/${my-openresty-env.api-gw.processUser}/openresty && cp -R ${my-openresty-src}/* /var/${my-openresty-env.api-gw.processUser}/openresty && chown -R ${my-openresty-env.api-gw.processUser}:${my-openresty-env.api-gw.processUser} /var/${my-openresty-env.api-gw.processUser}/openresty
      [ ! -d /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/logs ] && mkdir -p /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/logs && chown -R ${my-openresty-env.api-gw.processUser}:${my-openresty-env.api-gw.processUser} /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/logs
      [ ! -d /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/web/dumpfiles ] && mkdir -p /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/web/dumpfiles && chown -R nobody:nogroup /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/web/dumpfiles
      [ ! -d /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/web/parsereports ] && mkdir -p /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/web/parsereports && chown -R nobody:nogroup /var/${my-openresty-env.api-gw.processUser}/openresty/nginx/web/parsereports
      if [ ! -f /var/${my-openresty-env.api-gw.processUser}/openresty/env.export ]; then
         echo 'export DB_HOST=${my-openresty-config.db.host}' > /var/${my-openresty-env.api-gw.processUser}/openresty/env.export
         {
            echo 'export DB_PORT=${toString my-openresty-config.db.port}'
            echo 'export DB_USER=${my-openresty-config.db.apiSchemaUser}'
            echo 'export DB_PASS=${my-openresty-config.db.apiSchemaPassword}'
            echo 'export DB_NAME=${my-openresty-config.db.database}'
            echo 'export DB_SCHEMA=${my-openresty-config.db.apiSchema}'
            echo 'export JWT_SECRET=${my-openresty-config.db.jwtSecret}'
            echo 'export POSTGREST_HOST=${my-openresty-config.db-gw.server-host}'
            echo 'export POSTGREST_PORT=${toString my-openresty-config.db-gw.server-port}'
            echo 'export OPENRESTY_DOC_ROOT=${my-openresty-config.api-gw.docRoot}'
            echo 'export OPENRESTY_SERVER_NAME=${my-openresty-config.api-gw.serverName}'
            echo 'export OPENRESTY_LISTEN_PORT=${my-openresty-config.api-gw.listenPort}'
            echo 'export OPENRESTY_RESOLVER=${my-openresty-config.api-gw.resolver}'
            echo 'export OPENRESTY_UPLOAD_MAX_SIZE=${my-openresty-config.api-gw.uploadMaxSize}'
         }  >> /var/${my-openresty-env.api-gw.processUser}/openresty/env.export
      fi
      # shellcheck source=/dev/null
      . /var/${my-openresty-env.api-gw.processUser}/openresty/env.export
      openresty -p "/var/${my-openresty-env.api-gw.processUser}/openresty/nginx" -c "/var/${my-openresty-env.api-gw.processUser}/openresty/nginx/conf/nginx.conf" "$@"
    '';
  };

  # following define the service
  my-openresty-service = { lib, pkgs, config, ... }:
    {
      options = lib.attrsets.setAttrByPath [ "services" pkgName ] {
          enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
            description = "enable to generate a config to start the service";
          };
          # add extra options here, if any
        };
      config = lib.mkIf (lib.attrsets.getAttrFromPath [ pkgName "enable" ] config.services)
        (lib.attrsets.setAttrByPath [ "systemd" "services" pkgName ] {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          description = "${pkgName} service";
          serviceConfig = {
            Type = "forking";
            ExecStartPre = ''
              ${my-openresty-bin-sh}/bin/${my-openresty-bin-sh.name} -t -q -g "daemon on; master_process on;"
            '';
            ExecStart = ''
              ${my-openresty-bin-sh}/bin/${my-openresty-bin-sh.name} -g "daemon on; master_process on;"
            '';
            ExecReload = ''
              ${my-openresty-bin-sh}/bin/${my-openresty-bin-sh.name} -g "daemon on; master_process on;" -s reload
            '';
            ExecStop = "${my-openresty-bin-sh}/bin/${my-openresty-bin-sh.name} -s stop";
            Restart = "on-failure";
          };
        });
    };

  serviceNameKey = lib.concatStringsSep "." [ pkgName "service" ];
  serviceNameUnit = lib.attrsets.setAttrByPath [ serviceNameKey ] mk-my-openresty-service-unit;

  mk-my-openresty-service-unit = nPkgs.writeText serviceNameKey
    (lib.attrsets.getAttrFromPath [ "config" "systemd" "units" serviceNameKey "text" ] (nPkgs.nixos ({ lib, pkgs, config, ... }: {
      imports = [ my-openresty-service ];
    })));

in rec {
  inherit nativePkgs pkgs my-openresty-config;

  mk-my-openresty-service-systemd-setup-or-bin-sh = if my-openresty-env.api-gw.isSystemdService then
    (nPkgs.setupSystemdUnits {
      namespace = pkgName;
      units = serviceNameUnit;
    })
  else
    my-openresty-bin-sh;

  mk-my-openresty-reference = nPkgs.writeReferencesToFile mk-my-openresty-service-systemd-setup-or-bin-sh;
  mk-my-openresty-deploy-sh = release-utils.mk-deploy-sh {
    env = my-openresty-env.db-gw;
    payloadPath =  mk-my-openresty-service-systemd-setup-or-bin-sh;
    inherit innerTarballName;
    execName = "openresty";
  };
  mk-my-openresty-cleanup-sh = release-utils.mk-cleanup-sh {
    env = my-openresty-env.db-gw;
    payloadPath =  mk-my-openresty-service-systemd-setup-or-bin-sh;
    inherit innerTarballName;
    execName = "openresty";
  };
  mk-my-release-packer = release-utils.mk-release-packer {
    referencePath = mk-my-openresty-reference;
    component = pkgName;
    inherit site phase innerTarballName;
    deployScript = mk-my-openresty-deploy-sh;
    cleanupScript = mk-my-openresty-cleanup-sh;
  };
}
