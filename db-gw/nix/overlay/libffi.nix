self: prev:
prev.libffi.overrideAttrs (old: {
  dontDisableStatic = (if prev.stdenv.hostPlatform.isMusl then true else false);
})
