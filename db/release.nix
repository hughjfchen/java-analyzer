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

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  mk-release-pack =
    { reference # : AttrSet String Path
                # ^ A set whose names are site-phase and values are
                # either paths to the corresponding reference file
                # the name should include ".reference"
    , namespace # : String
                # The namespace for the reference files, to allow for
                # multiple independent deploy target
                # should be site-phase
    , deployScript # the deploy script path
    , cleanupScript # the cleanup script path
    }:
    let static = nPkgs.runCommand "reference-file-static" {}
          ''
            mkdir -p $out
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (nm: file:
                "ln -sv ${file} $out/${nm}"
             ) reference)}
          '';
        gen-changed-pkgs-list = name: file:
          ''
            oldReference=$(readlink -f "$referenceDir/${name}" || echo "$referenceDir/${name}")
            if [ -f "$oldReference" -a "$oldReference" != "${file}" ]; then
              LC_ALL=C comm -13 <(LC_ALL=C sort -u $oldReference) <(LC_ALL=C sort -u "${file}") > $referenceDir/reference-file.changed."${site}"."${phase}"
              fileListToPack="$referenceDir/reference-file.changed.${site}.${phase}"
            else
              fileListToPack="${file}"
            fi
            ln -sf "/nix/var/reference-file-static/${namespace}/${name}" \
              "$referenceDir/.${name}.tmp"
            mv -T "$referenceDir/.${name}.tmp" "$referenceDir/${name}"
          '';
    in
      nPkgs.writeScriptBin "mk-release-pack-for-${site}-${phase}"
        ''
          #!${nPkgs.bash}/bin/bash -e
          export PATH=${nPkgs.coreutils}/bin

          fileListToPack="${static}"

          referenceDir=/nix/var/reference-file
          mkdir -p "$referenceDir"

          oldStatic=$(readlink -f /nix/var/reference-file-static/${namespace} || true)
          if [ "$oldStatic" != "${static}" ]; then
            ${lib.concatStringsSep "\n"
                (lib.mapAttrsToList gen-changed-pkgs-list reference)}
            mkdir -p /nix/var/reference-file-static
            ln -sfT ${static} /nix/var/reference-file-static/.${namespace}.tmp
            mv -T /nix/var/reference-file-static/.${namespace}.tmp /nix/var/reference-file-static/${namespace}
          else
            echo "Dependence reference file unchanged, doing nothing" >&2
          fi

          # pack the systemd service or executable sh and dependencies with full path
          tar zPcf ./my-postgresql-full-pack-${site}-${phase}.tar.gz -T "$fileListToPack"

          # pack the previous tarball and the two scripts for distribution
          cp "${deployScript}/bin/mk-my-postgresql-deploy-sh" ./deploy-my-postgresql-to-${site}-${phase}
          cp "${cleanupScript}/bin/mk-my-postgresql-cleanup-sh" ./cleanup-my-postgresql-run-env-on-${site}-${phase}
          tar zcf ./my-postgresql-full-pack-dist-${site}-${phase}.tar.gz \
            ./my-postgresql-full-pack-${site}-${phase}.tar.gz \
            ./deploy-my-postgresql-to-${site}-${phase} \
            ./cleanup-my-postgresql-run-env-on-${site}-${phase}
          rm -fr ./my-postgresql-full-pack-${site}-${phase}.tar.gz ./deploy-my-postgresql-to-${site}-${phase} ./cleanup-my-postgresql-run-env-on-${site}-${phase}

        '';

  # the deployment env
  my-db-env-orig = (import ../env/site/${site}/phase/${phase}/env.nix { pkgs = nPkgs; }).env;
  # NOTICE: the postgresql process user must be postgres
  my-db-env = lib.attrsets.recursiveUpdate my-db-env-orig { db.processUser = "postgres";
                                                            db.configDir = "/var/postgres/config";
                                                            db.runDir = "/var/postgres/run";
                                                            db.dataDir = "/var/postgres/data";
                                                          };
  # the config
  my-db-config = (import ../config/site/${site}/phase/${phase}/config.nix { pkgs = nPkgs; env = my-db-env; }).config;
  
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
      cp -R $src/sql/authorization $out/
      cp -R $src/sql/sample_data $out/

      # replace the environment for the entry point file of the sql initialization
      sed "s/\$DB_ANON_ROLE/${my-db-config.db.anonRole}/g; s/\$DB_API_SCHEMA/${my-db-config.db.apiSchema}/g; s/\$DB_DATA_SCHEMA/${my-db-config.db.dataSchema}/g; s/\$DB_DATA_USER/${my-db-config.db.dataSchemaUser}/g; s/\$DB_DATA_PASS/${my-db-config.db.dataSchemaPassword}/g; s/\$DB_API_USER/${my-db-config.db.apiSchemaUser}/g; s/\$DB_API_PASS/${my-db-config.db.apiSchemaPassword}/g; s/\$DB_NAME/${my-db-config.db.database}/g; s/\$JWT_SECRET/${my-db-config.db.jwtSecret}/g; s/\$JWT_LIFETIME/${toString my-db-config.db.jwtLifeTime}/g" $src/sql/init.sql > $out/init.sql

      # for sql select statement, there can not be an evironement variable, so we must replace them before they can be loaded by psql
      mkdir -p $out/api
      for sqlFile in $src/sql/api/*
      do
        sed "s/\$DB_DATA_SCHEMA/${my-db-config.db.dataSchema}/g" $sqlFile > $out/api/$(basename $sqlFile)
      done
    '';
  };
  mk-my-postgresql-service-unit = (nPkgs.nixos ({ lib, pkgs, config, ... }: {
    config.services.postgresql = {
      enable = true;
      package = nPkgs.postgresql_9_6;
      port = 5432;
      dataDir = "${my-db-env.db.dataDir}";
      initdbArgs = [ "--encoding=UTF8" ];
      initialScript = my-db-init-script + /init.sql;
      ensureDatabases = [ ];
      ensureUsers = [ ];
      enableTCPIP = true;
      authentication = nPkgs.lib.mkOverride 10 ''
        local all all trust
        host all all all md5
      '';
      settings = { timezone = "Asia/Shanghai"; };
      #superUser = "postgres"; # read-only

    };
  })).config.systemd.units."postgresql.service".unit;

in rec {
  inherit nativePkgs pkgs my-db-config;

  mk-my-postgresql-service-systemd-setup-or-bin-sh = if my-db-env.db.isSystemdService then
    (nPkgs.setupSystemdUnits {
      namespace = "my-postgresql";
      units = {
        "my-postgresql.service" = mk-my-postgresql-service-unit
          + /postgresql.service;
      };
    })
  else
    { };
  mk-my-postgresql-reference = nPkgs.writeReferencesToFile mk-my-postgresql-service-systemd-setup-or-bin-sh;
  mk-my-postgresql-deploy-sh = nPkgs.writeScriptBin "mk-my-postgresql-deploy-sh"
    ''
    #!/usr/bin/env bash

    # this script need to be run with root or having sudo permission
    [ $EUID -ne 0 ] && ! sudo -v >/dev/null 2>&1 && echo "need to run with root or sudo" && exit 127

    # some command fix up for systemd service, especially web server
    getent group nogroup > /dev/null || sudo groupadd nogroup

    # create user and group
    getent group "${my-db-env.db.processUser}" > /dev/null || sudo groupadd "${my-db-env.db.processUser}"
    getent passwd "${my-db-env.db.processUser}" > /dev/null || sudo useradd -m -p Passw0rd -g "${my-db-env.db.processUser}" "${my-db-env.db.processUser}"

    # create directories
    for dirToMk in "${my-db-env.db.configDir}" "${my-db-env.db.runDir}" "${my-db-env.db.dataDir}"
    do
      if [ ! -d "$dirToMk" ]; then
         sudo mkdir -p "$dirToMk"
         sudo chown -R ${my-db-env.db.processUser}:${my-db-env.db.processUser} "$dirToMk"
      fi
    done

    # now unpack(note we should preserve the /nix/store directory structure)
    sudo tar zPxf ./my-postgresql-full-pack-${site}-${phase}.tar.gz
    sudo chown -R ${my-db-env.db.processUser}:${my-db-env.db.processUser} /nix

    # setup the systemd service or create a link to the executable
    ${lib.concatStringsSep "\n"
                (if my-db-env.db.isSystemdService then
                  ["sudo ${mk-my-postgresql-service-systemd-setup-or-bin-sh}/bin/setup-systemd-units"]
                 else [
                  "ln -s ${mk-my-postgresql-service-systemd-setup-or-bin-sh}/bin/postgres ${my-db-env.db.runDir}/postgres"
                  "echo \"To use the program, type ${my-db-env.db.runDir}/postgres at the command prompt.\""
                 ]
                 )}

    '';
  mk-my-postgresql-cleanup-sh = nPkgs.writeScriptBin "mk-my-postgresql-cleanup-sh"
    ''
    #!/usr/bin/env bash

    # this script need to be run with root or having sudo permission
    [ $EUID -ne 0 ] && ! sudo -v >/dev/null 2>&1 && echo "need to run with root or sudo" && exit 127

    # how do we unsetup the systemd unit? we do not unsetup the systemd service for now
    # we just stop it before doing the cleanup
    ${lib.concatStringsSep "\n"
      (if my-db-env.db.isSystemdService then
        ["sudo systemctl stop my-postgresql.service"]
       else
         ["${my-db-env.db.runDir}/postgres --command=Stop"])}

    for dirToRm in "${my-db-env.db.configDir}" "${my-db-env.db.runDir}" "${my-db-env.db.dataDir}"
    do
      if [ -d "$dirToRm" ]; then
         sudo rm -fr "$dirToRm"
      fi
    done

    # do we need to delete the program and all its dependencies in /nix/store?
    # we do not do that for now
    # sudo rm -fr /nix/store/xxx ( maybe a file list for the package and its references )

    # well, shall we remove the user and group? maybe not
    # we do not do that for now.
    # getent passwd "${my-db-env.db.processUser}" > /dev/null && sudo userdel -fr "${my-db-env.db.processUser}"
    # getent group "${my-db-env.db.processUser}" > /dev/null && sudo groupdel -f "${my-db-env.db.processUser}"

    '';
  mk-dist-full-pack = nPkgs.writeShellApplication {
    name = "mk-dist-full-pack-${site}-${phase}";
    runtimeInputs = [];
    text = ''
      # pack the systemd service or executable sh and dependencies with full path
      tar zPcf ./my-postgresql-full-pack-${site}-${phase}.tar.gz -T "${mk-my-postgresql-reference}"

      # pack the previous tarball and the two scripts for distribution
      cp "${mk-my-postgresql-deploy-sh}/bin/mk-my-postgresql-deploy-sh" ./deploy-my-postgresql-to-${site}-${phase}
      cp "${mk-my-postgresql-cleanup-sh}/bin/mk-my-postgresql-cleanup-sh" ./cleanup-my-postgresql-run-env-on-${site}-${phase}
      tar zcf ./my-postgresql-full-pack-dist-${site}-${phase}.tar.gz \
        ./my-postgresql-full-pack-${site}-${phase}.tar.gz \
        ./deploy-my-postgresql-to-${site}-${phase} \
        ./cleanup-my-postgresql-run-env-on-${site}-${phase}
      rm -fr ./my-postgresql-full-pack-${site}-${phase}.tar.gz ./deploy-my-postgresql-to-${site}-${phase} ./cleanup-my-postgresql-run-env-on-${site}-${phase}
    '';
  };
  mk-dist-delta-pack = nPkgs.writeShellApplication {
    name = "mk-delta-full-pack-${site}-${phase}";
    runtimeInputs = [];
    text = ''
      tar zPcf my-postgresql-full-pack.tar.gz -T "${mk-my-postgresql-reference}"
      ln -s "${mk-my-postgresql-deploy-sh}" ./deploy-my-postgresql
      ln -s "${mk-my-postgresql-cleanup-sh}" ./undeploy-my-postgresql
      tar zcf my-postgresql-full-pack_dist.tar.gz my-postgresql-full-pack.tar.gz ./deploy-my-postgresql ./undeploy-my-postgresql
      rm -fr ./deploy-my-postgresql ./undeploy-my-postgresql
    '';
  };
  mk-my-postgresql-release-pack = mk-release-pack {
    reference = { "${site}-${phase}.reference" = mk-my-postgresql-reference; };
    namespace = "${site}-${phase}";
    deployScript = mk-my-postgresql-deploy-sh;
    cleanupScript = mk-my-postgresql-cleanup-sh;
  };
}
