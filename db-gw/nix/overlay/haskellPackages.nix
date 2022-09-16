self: prev:
prev.haskellPackages.override {
  overrides = selfHP: prevHP: {
    postgresql-libpq = prevHP.postgresql-libpq.overrideAttrs (old: {
      configureFlags = old.configureFlags ++ [ "-f use-pkg-config" ];
      buildInputs = [ prev.pkg-config ] ++ old.buildInputs;
      nativeBuildInputs = old.nativeBuildInputs ++ [ prev.pkg-config ];
    });
  };
}
