self: prev:
prev.haskellPackages.override {
  overrides = selfHP: prevHP: {
    postgresql-libpq = prevHP.postgresql-libpq.overrideAttrs (old: {
      configureFlags = old.configureFlags ++ [ "-f use-pkg-config" ];
      buildInputs = [ prev.pkg-config ] ++ old.buildInputs;
      nativeBuildInputs = old.nativeBuildInputs ++ [ prev.pkg-config ];
    });
    postgrest = prevHP.postgrest.overrideAttrs (old: {
      configureFlags = (if prev.stdenv.hostPlatform.isMusl then
        old.configureFlags ++ [
          "--ghc-option=-optl=-lssl"
          "--ghc-option=-optl=-lcrypto"
          "--ghc-option=-optl=-L${prev.openssl.out}/lib"
          "--ghc-option=-optl=-lpgcommon"
          "--ghc-option=-optl=-lpgport"
          "--ghc-option=-optl=-L${prev.postgresql.out}/lib"
        ]
      else
        old.configureFlags);

    });
  };
}
