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
  pkgName = "my-frontend";
  innerTarballName = lib.concatStringsSep "." [
    (lib.concatStringsSep "-" [ pkgName site phase ])
    "tar"
    "gz"
  ];

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  deploy-packer = import (builtins.fetchGit {
    url = "https://github.com/hughjfchen/deploy-packer";
    rev = "edb44c76c64e537cfc63938cea1e7acf03e0484c";
    # sha256 = "0r4y9nvmjkx7xf79m2i8qyrs7gp188adkfggg1p1q8vxfv0y4ilj";
  }) {
    inherit lib;
    pkgs = nPkgs;
  };

  # the deployment env
  my-openresty-env = (import (builtins.fetchGit {
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
  my-openresty-config = (import (builtins.fetchGit {
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
    env = my-openresty-env;
  }).config;

  # the frontend, comment out for now.
  my-frontend-distributable =
    (import ../frontend/default.nix { }).java-analyzer-frontend.overrideAttrs
    (oldAttrs: {
      buildPhase = ''
        # following not working, do not know why
        # rm -fr .env.production.local .env.local .env.production
        # echo "REACT_APP_BASE_URL=http://${my-openresty-config.api-gw.serverName}:${
          toString my-openresty-config.api-gw.listenPort
        }" > .env.production
        sed -i 's/{process.env.REACT_APP_BASE_URL}/http:\/\/${my-openresty-config.api-gw.serverName}:${
          toString my-openresty-config.api-gw.listenPort
        }/g' src/dataprovider.js
        sed -i 's/{process.env.REACT_APP_BASE_URL}/http:\/\/${my-openresty-config.api-gw.serverName}:${
          toString my-openresty-config.api-gw.listenPort
        }/g' src/auth.js
      '' + oldAttrs.buildPhase;
    });

in my-frontend-distributable
