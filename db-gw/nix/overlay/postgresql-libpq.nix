self: prev:
prev.postgresql-libpq.overrideAttrs
(old: { configFlags = old.configFlags ++ [ "-f use-pkg-config" ]; })
