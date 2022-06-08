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
  pkgName = "my-rabbitmq";
  innerTarballName = lib.concatStringsSep "." [ (lib.concatStringsSep "-" [ pkgName site phase ]) "tar" "gz" ];

  # define some utility function for release packing ( code adapted from setup-systemd-units.nix )
  release-utils = import ./release-utils.nix { inherit lib; pkgs = nPkgs; };

  # the deployment env
  my-messaging-env-orig = (import ../env/site/${site}/phase/${phase}/env.nix { pkgs = nPkgs; }).env;
  # NOTICE: the rabbitmq process user must be rabbitmq
  my-messaging-env = lib.attrsets.recursiveUpdate my-messaging-env-orig { messaging.processUser = "rabbitmq";
                                                            messaging.runDir = "/var/rabbitmq/run";
                                                            messaging.dataDir = "/var/rabbitmq/data";
                                                          };

  # the config
  my-messaging-config = (import ../config/site/${site}/phase/${phase}/config.nix { pkgs = nPkgs; env = my-messaging-env; }).config;
  
  # my services dependencies
  # following define the service
  mk-my-rabbitmq-service-unit = (nPkgs.nixos ({ lib, pkgs, config, ... }: {
    config.services.rabbitmq = {
      enable = true;
      package = nPkgs.rabbitmq-server;
      listenAddress = "${my-messaging-env.messaging.ipAddress}";
      port = 5672;
      dataDir = "${my-messaging-env.messaging.dataDir}";
      cookie = "";
      configItems = { "num_acceptors.tcp" = "10";
                     "channel_max" = "2047";
                    "max_message_size" = "134217728";
                    "log.file.level" = "info";
                    "default_user" = "${my-messaging-env.messaging.processUser}";
                    "default_pass" = "Passw0rd";
                    "default_user_tags.administrator" = "true";
                    "default_permissions.configure" = ".*";
                    "default_permissions.read" = ".*";
                    "default_permissions.write" = ".*";
                    };
      config = ''
      '';
      plugins = [  ];
      pluginDirs = [  ];
      managementPlugin = { enable = true;
                           port = 15672;
                         };

    };
  })).config.systemd.units."rabbitmq.service".unit;

  serviceNameKey = lib.concatStringsSep "." [ pkgName "service" ];
  serviceNameUnit = lib.attrsets.setAttrByPath [ serviceNameKey ] (mk-my-rabbitmq-service-unit + /rabbitmq.service);
in rec {
  inherit nativePkgs pkgs my-messaging-config;

  mk-my-rabbitmq-service-systemd-setup-or-bin-sh = if my-messaging-env.messaging.isSystemdService then
    (nPkgs.setupSystemdUnits {
      namespace = pkgName;
      units = serviceNameUnit;
    })
  else
    { };
  mk-my-rabbitmq-reference = nPkgs.writeReferencesToFile mk-my-rabbitmq-service-systemd-setup-or-bin-sh;
  mk-my-rabbitmq-deploy-sh = release-utils.mk-deploy-sh {
    env = my-messaging-env.messaging;
    payloadPath =  mk-my-rabbitmq-service-systemd-setup-or-bin-sh;
    inherit innerTarballName;
    execName = "rabbitmq";
  };
  mk-my-rabbitmq-cleanup-sh = release-utils.mk-cleanup-sh {
    env = my-messaging-env.messaging;
    payloadPath =  mk-my-rabbitmq-service-systemd-setup-or-bin-sh;
    inherit innerTarballName;
    execName = "rabbitmq";
  };
  mk-my-release-packer = release-utils.mk-release-packer {
    referencePath = mk-my-rabbitmq-reference;
    component = pkgName;
    inherit site phase innerTarballName;
    deployScript = mk-my-rabbitmq-deploy-sh;
    cleanupScript = mk-my-rabbitmq-cleanup-sh;
  };
}
