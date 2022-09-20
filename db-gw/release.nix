{ nativePkgs ? import ./default.nix { }, # the native package set
pkgs ? import ./cross-build.nix { }
, # the package set for corss build, we're especially interested in the fully static binary
site, # the site for release, the binary would deploy to it finally
phase, # the phase for release, must be "local", "test" and "production"
}:
let
  nPkgs = nativePkgs.pkgs;
  sPkgs = pkgs.x86-musl64; # for the fully static build
  lib = nPkgs.lib; # lib functions from the native package set
  pkgName = "my-postgrest";
  innerTarballName = lib.concatStringsSep "." [
    (lib.concatStringsSep "-" [ pkgName site phase ])
    "tar"
    "gz"
  ];

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  deploy-packer = import (builtins.fetchGit {
    url = "https://github.com/hughjfchen/deploy-packer";
    rev = "43df28eb692ecf9ebed02c25c39bd30bea67080a";
    # sha256 = "0r4y9nvmjkx7xf79m2i8qyrs7gp188adkfggg1p1q8vxfv0y4ilj";
  }) {
    inherit lib;
    pkgs = nPkgs;
  };

  # the deployment env
  my-postgrest-env = (import (builtins.fetchGit {
    url = "https://github.com/hughjfchen/deploy-env";
    rev = "a82e45e4a4968ec8ecc242cca00e67cc5c1f875b";
    # sha256 = "159jxp47572whi2kpykl2mpawhx70n51jmmxm1ga6xq6a48vpqpy";
  }) {
    pkgs = nPkgs;
    modules = [
      ../env/site/${site}/phase/${phase}/db.nix
      ../env/site/${site}/phase/${phase}/db-gw.nix
      ../env/site/${site}/phase/${phase}/api-gw.nix
      ../env/site/${site}/phase/${phase}/messaging.nix
      ../env/site/${site}/phase/${phase}/runner.nix
    ];
  }).env;

  # the config
  my-postgrest-config = (import (builtins.fetchGit {
    url = "https://github.com/hughjfchen/deploy-config";
    rev = "994fcf8c57fdcc2b1c88f5c724ee7b7d09f48337";
    # sha256 = "17kffymnv0fi6fwzc70ysv1w1ry99cq6h8440jv2x9hsd9vrzs3q";
  }) {
    pkgs = nPkgs;
    modules = [
      ../config/site/${site}/phase/${phase}/db.nix
      ../config/site/${site}/phase/${phase}/db-gw.nix
      ../config/site/${site}/phase/${phase}/api-gw.nix
      ../config/site/${site}/phase/${phase}/messaging.nix
      ../config/site/${site}/phase/${phase}/runner.nix
    ];
    env = my-postgrest-env;
  }).config;

  # my services dependencies
  # following define the service
  my-postgrest-config-kv = nPkgs.writeTextFile {
    name = lib.concatStringsSep "-" [ pkgName "config" ];
    # generate the key = value format config, refer to the lib.generators for other formats
    text = (lib.generators.toKeyValue { }) my-postgrest-config.db-gw;
  };

  # my services dependencies
  my-postgrest-bin-sh = nPkgs.writeShellApplication {
    name = lib.concatStringsSep "-" [ pkgName "bin" "sh" ];
    runtimeInputs = [ sPkgs.postgrest.postgrest-exe ];
    text = ''
      postgrest ${my-postgrest-config-kv} "$@"
    '';
  };

  # following define the service
  my-postgrest-service = { lib, pkgs, config, ... }:
    let cfg = config.services.my-postgrest;
    in {
      options = lib.attrsets.setAttrByPath [ "services" pkgName ] {
        enable = lib.mkOption {
          default = true;
          type = lib.types.bool;
          description = "enable to generate a config to start the service";
        };
        # add extra options here, if any
      };
      config = lib.mkIf cfg.enable
        (lib.attrsets.setAttrByPath [ "systemd" "services" pkgName ] {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          description = "my postgrest service";
          serviceConfig = {
            Type = "simple";
            User = "${my-postgrest-env.db-gw.processUser}";
            ExecStart =
              "${my-postgrest-bin-sh}/bin/${my-postgrest-bin-sh.name}";
            Restart = "on-failure";
          };
        });
    };

  serviceNameKey = lib.concatStringsSep "." [ pkgName "service" ];
  serviceNameUnit = lib.attrsets.setAttrByPath [ serviceNameKey ] {
    path = mk-my-postgrest-service-unit;
    wanted-by = [ "multi-user.target" ];
  };

  mk-my-postgrest-service-unit = nPkgs.writeText serviceNameKey
    (lib.attrsets.getAttrFromPath [
      "config"
      "systemd"
      "units"
      serviceNameKey
      "text"
    ] (nPkgs.nixos
      ({ lib, pkgs, config, ... }: { imports = [ my-postgrest-service ]; })));

in rec {
  inherit nativePkgs pkgs my-postgrest-config-kv;

  mk-my-postgrest-service-systemd-setup-or-bin-sh =
    if my-postgrest-env.db-gw.isSystemdService then
      (nPkgs.setupSystemdUnits {
        namespace = pkgName;
        units = serviceNameUnit;
      })
    else
      my-postgrest-bin-sh;

  mk-my-postgrest-service-systemd-unsetup-or-bin-sh =
    if my-postgrest-env.db-gw.isSystemdService then
      (deploy-packer.unsetup-systemd-service {
        namespace = pkgName;
        units = serviceNameUnit;
      })
    else
      { };
  # following derivation just to make sure the setup and unsetup will
  # be packed into the distribute tarball.
  setup-and-unsetup-or-bin-sh = nPkgs.symlinkJoin {
    name = "my-postgrest-setup-and-unsetup";
    paths = [
      mk-my-postgrest-service-systemd-setup-or-bin-sh
      mk-my-postgrest-service-systemd-unsetup-or-bin-sh
    ];
  };

  mk-my-postgrest-reference =
    nPkgs.writeReferencesToFile setup-and-unsetup-or-bin-sh;
  mk-my-postgrest-deploy-sh = deploy-packer.mk-deploy-sh {
    env = my-postgrest-env.db-gw;
    payloadPath = setup-and-unsetup-or-bin-sh;
    inherit innerTarballName;
    execName = "postgrest";
  };
  mk-my-postgrest-cleanup-sh = deploy-packer.mk-cleanup-sh {
    env = my-postgrest-env.db-gw;
    payloadPath = setup-and-unsetup-or-bin-sh;
    inherit innerTarballName;
    execName = "postgrest";
  };
  mk-my-release-packer = deploy-packer.mk-release-packer {
    referencePath = mk-my-postgrest-reference;
    component = pkgName;
    inherit site phase innerTarballName;
    deployScript = mk-my-postgrest-deploy-sh;
    cleanupScript = mk-my-postgrest-cleanup-sh;
  };

}
