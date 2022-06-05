{ modules ? [ ], pkgs, ... }:
#{ modules ? [ ], pkgs, hostName, dnsName, ipAddress, processUser, isSystemdService
#, configDir, runDir, dataDir, ... }:

let _pkgs = pkgs;
in let
  pkgs = if builtins.typeOf _pkgs == "path" then
    import _pkgs
  else if builtins.typeOf _pkgs == "set" then
    _pkgs
  else
    builtins.abort
    "The pkgs argument must be an attribute set or a path to an attribute set.";

  inherit (pkgs);
  lib = pkgs.lib;

  envBuilder = lib.evalModules { modules = builtinModules ++ modules; };

  builtinModules = [ argsModule ] ++ import ../../../../module-list.nix
    ++ import ./module-list.nix;

  argsModule = {
    _file = ./env-builder.nix;
    key = ./env-builder.nix;
    config._module.check = true;
    config._module.args.pkgs = lib.mkIf (pkgs != null) (lib.mkForce pkgs);
    # config.hostName = hostName;
    # config.dnsName = dnsName;
    # config.ipAddress = ipAddress;
    # config.processUser = processUser;
    # config.isSystemdService = isSystemdService;
    # config.configDir = configDir;
    # config.runDir = runDir;
    # config.dataDir = dataDir;
  };

in { env = lib.attrByPath [ "config" ] { } envBuilder; } // {
  # throw in lib and pkgs for repl convenience
  inherit lib;
  inherit (envBuilder._module.args) pkgs;
}
