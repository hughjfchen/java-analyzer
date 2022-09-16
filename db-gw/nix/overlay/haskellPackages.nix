self: prev:
prev.haskellPackages.override {
  overrides = selfHP: prevHP: {
    postgresql-libpq = prevHP.postgresql-libpq.overrideAttrs (old: {
      configureFlags = old.configureFlags ++ [ "-f use-pkg-config" ];
      buildInputs = old.buildInputs ++ [ prev.pkg-config ];
    });
  };
}
