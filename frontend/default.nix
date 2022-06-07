let
  sources = import ./nix/sources.nix;
  # Fetch the latest haskell.nix and import its default.nix
  haskellNix = import sources."haskell.nix" { };
  # haskell.nix provides access to the nixpkgs pins which are used by our CI, hence
  # you will be more likely to get cache hits when using these.
  # But you can also just use your own, e.g. '<nixpkgs>'
  #nixpkgsSrc = if haskellNix.pkgs.stdenv.hostPlatform.isDarwin then sources.nixpkgs-darwin else haskellNix.sources.nixpkgs-2111;
  # no need to check platform now
  nixpkgsSrc = haskellNix.sources.nixpkgs-2111;
  # haskell.nix provides some arguments to be passed to nixpkgs, including some patches
  # and also the haskell.nix functionality itself as an overlay.
  nixpkgsArgs = haskellNix.nixpkgsArgs;
in { nativePkgs ? import nixpkgsSrc (nixpkgsArgs // {
  overlays = nixpkgsArgs.overlays ++ [ (import ./nix/overlay) ];
}), haskellCompiler ? "ghc8107", customModules ? [ ] }:
let
  pkgs = nativePkgs;
  # 'cabalProject' generates a package set based on a cabal.project (and the corresponding .cabal files)
in rec {
  # inherit the pkgs package set so that others importing this function can use it
  inherit pkgs;

  # nativePkgs.lib.recurseIntoAttrs, just a bit more explicilty.
  recurseForDerivations = true;

  java-analyzer-frontend = pkgs.mkYarnPackage rec {
    pname = "java-analyzer-frontend";
    version = "0.0.0.1";
    src = ./.;
    packageJSON = ./package.json;
    yarnLock = ./yarn.lock;
    yarnNix = ./yarn.nix;
    # following is to build a static asset, not to build a binary
    # inspired by nixpkgs/servers/gotify/ui.nix
    buildPhase = ''
      export HOME=$(mktemp -d)
      export WRITABLE_NODE_MODULES="$(pwd)/tmp"
      mkdir -p "$WRITABLE_NODE_MODULES"
      # react-scripts requires a writable node_modules/.cache, so we have to copy the symlink's contents back
      # into `node_modules/`.
      # See https://github.com/facebook/create-react-app/issues/11263
      cd deps/${pname}
      node_modules="$(readlink node_modules)"
      rm node_modules
      mkdir -p "$WRITABLE_NODE_MODULES"/.cache
      cp -r $node_modules/* "$WRITABLE_NODE_MODULES"
      # In `node_modules/.bin` are relative symlinks that would be broken after copying them over,
      # so we take care of them here.
      mkdir -p "$WRITABLE_NODE_MODULES"/.bin
      for x in "$node_modules"/.bin/*; do
        ln -sfv "$node_modules"/.bin/"$(readlink "$x")" "$WRITABLE_NODE_MODULES"/.bin/"$(basename "$x")"
      done
      ln -sfv "$WRITABLE_NODE_MODULES" node_modules
      cd ../..
      yarn build
      cd deps/${pname}
      rm -rf node_modules
      ln -sf $node_modules node_modules
      cd ../..
    '';
    # distPhase = "true";
    # configurePhase = "ln -s $node_modules node_modules";
  };

}
