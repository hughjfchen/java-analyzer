{
  nativePkgs ? import ./default.nix {}, # the native package set
  pkgs ? import ./cross-build.nix {}, # the package set for corss build, we're especially interested in the fully static binary
  releasePhase, # the phase for release, must be "local", "test" and "production"
  releaseHost, # the hostname for release,the binary would deploy to it finally
  genSystemdUnit ? true, # whether should generate a systemd unit and a setup script for the binary
  userName ? "", # the user name on the target machine. If empty, use the user on the build machine for program directory, root for running program
  dockerOnTarget ? false # whether docker/docker-compose is needed on the target machine
}:
let
  nPkgs = nativePkgs.pkgs;
  sPkgs = pkgs.x86-musl64; # for the fully static build
  lib = nPkgs.lib; # lib functions from the native package set

  # extra runtime dependencies
  ibm-dtfj-p2-site = nPkgs.stdenv.mkDerivation rec {
    name = "ibm-dtfj-p2-site";
    pkgprefix = "com.ibm.dtfj";
    version = "1.12.29003.202006111057";
    src = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/p2.index";
      sha256 = "1kgn7jgndv52zd9v4cw2511i5d99k759fgykvpv7lfll12s1r46j";
    };
    content-jar = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/content.jar";
      sha256 = "0g2bnv74nh14i5lwrlhfafr9x5wa69jl34529bbchmm31z8yar2w";
    };
    content-xml-xz = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/content.xml.xz";
      sha256 = "1m3nzqw9fa4b78m98j9k16n6qnwgw77w3m46kdji858kyhg5gys9";
    };
    artifacts-jar = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/artifacts.jar";
      sha256 = "1d4djss1m2vclpy4hnps76f8sp5qq01rmzji30734sj0mhcw4x5i";
    };
    artifacts-xml-xz = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/artifacts.xml.xz";
      sha256 = "1d3g7xixn0yh0hdx2dfdv4nav6pf3955ljhlprs2526y5p6ks2ns";
    };
    features-jar = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/features/${pkgprefix}.feature_${version}.jar";
      sha256 = "1jfmb96qn422wrqkkbmd8n0lgdpx0c2g2lbhas00j8020w29yiw8";
    };
    plugins-api-jar = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/plugins/${pkgprefix}.api_${version}.jar";
      sha256 = "0qcmhdh2skbjqmfi42sq4i7zfr2arkvna0qb3k4ci1d36c21d4y1";
    };
    plugins-j9-jar = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/runtimes/tools/dtfj/plugins/${pkgprefix}.j9_${version}.jar";
      sha256 = "1v2vs3xwngsqsvy2vhajqm3i42dx8j99yacir1sp7xbicx5cdiy6";
    };
    dontUnpack = true;
    unpackPhase = "";
    buildCommand = ''
      mkdir -p $out
      mkdir -p $out/features
      mkdir -p $out/plugins
      cp $src $out/$(stripHash $src)
      cp ${content-jar} $out/$(stripHash ${content-jar})
      cp ${content-xml-xz} $out/$(stripHash ${content-xml-xz})
      cp ${artifacts-jar} $out/$(stripHash ${artifacts-jar})
      cp ${artifacts-xml-xz} $out/$(stripHash ${artifacts-xml-xz})
      cp ${features-jar} $out/features/$(stripHash ${features-jar})
      cp ${plugins-api-jar} $out/plugins/$(stripHash ${plugins-api-jar})
      cp ${plugins-j9-jar} $out/plugins/$(stripHash ${plugins-j9-jar})
    '';
  };

  # eclipse package and plugins
  my-eclipse-mat-with-dtfj = nPkgs.eclipse-mat.overrideAttrs (oldAttrs: { buildCommand = oldAttrs.buildCommand + ''
                                            # add ibm dtfj plugin to support ibm jdk heapdump
                                            P2_DIRECTOR=org.eclipse.equinox.p2.director
                                            DTFJ_REPO=file:${ibm-dtfj-p2-site}
                                            DTFJ_FEATURE=${ibm-dtfj-p2-site.pkgprefix}.feature.feature.group
                                            $out/mat/MemoryAnalyzer -application $P2_DIRECTOR -repository $DTFJ_REPO -installIU $DTFJ_FEATURE
                                            # sed '/-vmargs/ i -vm\n${nPkgs.jdk11}/bin' $out/mat/MemoryAnalyzer.ini > $out/mat/MemoryAnalyzer.jdk11.ini
                                            awk '/-vmargs/ {print "-vm\n${nPkgs.jdk11}/bin"} 1' $out/mat/MemoryAnalyzer.ini > $out/mat/MemoryAnalyzer.jdk11.ini
                                            cp $out/mat/MemoryAnalyzer.jdk11.ini $out/mat/MemoryAnalyzer.ini
                                            rm -fr $out/mat/MemoryAnalyzer.jdk11.ini
                                            '';});
  # java jar packages
  my-jca = nPkgs.stdenv.mkDerivation {
    name = "my-jca";
    version = "4611";
    src = builtins.fetchurl {
      url = "https://public.dhe.ibm.com/software/websphere/appserv/support/tools/jca/jca4611.jar";
      sha256 = "16wrbxl229qr4bnmdpdi1swmgfgy8irq35gmbcicgaq3grga781q";
    };
    dontBuild = true;
    dontUnpack = true;
    unpackPhase = "";
    installPhase = ''
      mkdir -p $out/share/java
      cp $src $out/share/java/
    '';
  };

  my-jca-sh = nPkgs.writeShellApplication {
    name = "my-jca-sh";
    runtimeInputs = [ nPkgs.xvfb-run nPkgs.jdk11 ];
    text = ''
      xvfb-run -a java -jar ${my-jca.src} "$@"
    '';
  };
  # the config
  # dependent config
  my-db-config = (import ../db/release.nix {
    inherit releasePhase releaseHost genSystemdUnit userName dockerOnTarget;
  }).my-db-config;

  java-analyzer-runner-config = nPkgs.writeTextFile {
    name = "java-analyzer-runner-config";
    # generate the key = value format config, refer to the lib.generators for other formats
    text = (lib.generators.toKeyValue {}) (import ./config/${releasePhase}/${releaseHost} { pkgs = nPkgs // { inherit my-db-config releasePhase releaseHost genSystemdUnit userName dockerOnTarget my-eclipse-mat-with-dtfj my-jca; }; });
  };
  java-analyzer-runner-bin-sh-paths = [
    # list the runtime dependencies, especially those cannot be determined by nix automatically
    nPkgs.wget
    nPkgs.curl
    nPkgs.xvfb-run
    nPkgs.jdk11
    my-eclipse-mat-with-dtfj
    my-jca-sh
    sPkgs.java-analyzer-runner.java-analyzer-runner-exe
  ];
  java-analyzer-runner-bin-sh = nPkgs.writeShellApplication {
    name = "java-analyzer-runner-bin-sh";
    runtimeInputs = java-analyzer-runner-bin-sh-paths;
    # wrap the executable, suppose it accept a --config commandl ine option to load the config
    text = ''
      [ ! -f /var/${userName}/config/java-analyzer-runner.properties ] && cp ${java-analyzer-runner-config} /var/${userName}/config/java-analyzer-runner.properties
      java-analyzer-runner --config.file="/var/${userName}/config/java-analyzer-runner.properties" "$@"
    '';
  };
  # following define the service
  java-analyzer-runner-service = { lib, pkgs, config, ... }:
      let
        cfg = config.services.java-analyzer-runner;
      in
        {
          options = {
            services.java-analyzer-runner = {
              enable = lib.mkOption {
                default = true;
                type = lib.types.bool;
                description = "enable to generate a config to start the service";
              };
              # add extra options here, if any
            };
          };
          config = lib.mkIf cfg.enable {
            systemd.services.java-analyzer-runner = {
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];
              description = "java-analyzer-runner service";
              serviceConfig = {
                Type = "forking";
                User = "${userName}";
                ExecStart = ''${java-analyzer-runner-bin-sh}/bin/java-analyzer-runner-bin-sh --command=Start'';
                Restart = "on-failure";
              };
            };
          };
        };
  mk-java-analyzer-runner-service-unit = nPkgs.writeText "java-analyzer-runner.service" (nPkgs.nixos ( { lib, pkgs, config, ... }:
      {
        imports = [ java-analyzer-runner-service ];
      })
  ).config.systemd.units."java-analyzer-runner.service".text;
in
{ inherit nativePkgs pkgs ibm-dtfj-p2-site my-eclipse-mat-with-dtfj java-analyzer-runner-config;
  mk-java-analyzer-runner-service-systemd-setup-or-bin-sh = if genSystemdUnit then
    (nPkgs.setupSystemdUnits {
      namespace = "java-analyzer-runner";
      units = {
        "java-analyzer-runner.service" = mk-java-analyzer-runner-service-unit;
      };
    }) else java-analyzer-runner-bin-sh;
}
