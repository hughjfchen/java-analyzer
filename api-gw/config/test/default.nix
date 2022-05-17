{ pkgs }:
with pkgs.lib;
mapAttrs' (attr: _: {
  name = removeSuffix ".nix" attr;
  value = import (./. + "/${attr}") { inherit pkgs; };
}) (filterAttrs (fname: type: type == "regular" && fname != "default.nix")
  (builtins.readDir ./.))
