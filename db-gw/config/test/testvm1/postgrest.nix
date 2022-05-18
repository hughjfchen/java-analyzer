{ pkgs, lib, config, ... }:
let inherit pkgs lib config;
in {
  "db-uri" = ''
    "postgres://${config.my-db-config.db.user}:${config.my-db-config.db.password}@${config.my-db-config.db.host}:${
      toString config.my-db-config.db.port
    }/${config.my-db-config.db.database}"'';
  "db-anon-role" = ''"${config.my-db-config.db.anonymousRole}"'';
  "db-schema" = ''"${config.my-db-config.db.schema}"'';
  "jwt-secret" = ''"${config.my-db-config.db.jwtSecret}"'';
  "server-host" = ''"testvm1"'';
  "server-port" = 3000;
}
