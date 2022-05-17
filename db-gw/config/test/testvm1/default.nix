{ pkgs }:
with pkgs.lib;
let
  upPkgs = import ../default.nix { inherit pkgs; };
  mergePkgs = recursiveUpdate pkgs upPkgs;
in recursiveUpdate mergePkgs (mapAttrs' (attr: _: {
  name = removeSuffix ".nix" attr;
  value = import (./. + "/${attr}") { pkgs = mergePkgs; };
}) (filterAttrs (fname: type: type == "regular" && fname != "default.nix")
  (builtins.readDir ./.)))
