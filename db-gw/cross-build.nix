{ defaultPlatformProject ? import ./default.nix { }
, toBuild ? import ./nix/cross-build/systems.nix defaultPlatformProject.pkgs }:
# map through the system list
defaultPlatformProject.pkgs.lib.mapAttrs (_: pkgs:
  let
    myHaskellPackages = pkgs.haskellPackages.override {
      overrides = selfHP: prevHP: {
        postgresql-libpq = prevHP.postgresql-libpq.overrideAttrs (old: {
          configureFlags = old.configureFlags ++ [ "-f use-pkg-config" ];
          # buildInputs = [ prev.pkg-config ] ++ old.buildInputs;
          # nativeBuildInputs = old.nativeBuildInputs ++ [ prev.pkg-config ];
        });
        postgrest = prevHP.postgrest.overrideAttrs (old: {
          configureFlags = (if pkgs.stdenv.hostPlatform.isMusl then
            old.configureFlags ++ [
              "--enable-executable-static"
              "--ghc-option=-optl=-lssl"
              "--ghc-option=-optl=-lcrypto"
              "--ghc-option=-optl=-L${pkgs.openssl.out}/lib"
              "--ghc-option=-optl=-lpgcommon"
              "--ghc-option=-optl=-lpgport"
              "--ghc-option=-optl=-L${pkgs.postgresql.out}/lib"
            ]
          else
            old.configureFlags);

        });
      };
    };
  in rec {
    # nativePkgs.lib.recurseIntoAttrs, just a bit more explicilty.
    recurseForDerivations = true;

    myPostgrest = myHaskellPackages.postgrest;

  }) toBuild
