{ pkgs }:
let inherit pkgs;
in {
  "db-uri" =
    "postgres://${pkgs.my-db-config.db.user}:${pkgs.my-db-config.db.password}@${pkgs.my-db-config.db.host}:${pkgs.my-db-config.db.port}/${pkgs.my-db-config.db.database}";
  "db-anon-role" = "${pkgs.my-db-config.db.anonymousRole}";
  "db-schema" = "${pkgs.my-db-config.db.schema}";
  "jwt-secret" = "${pkgs.my-db-config.db.jwtSecret}";
  "server-host" = "testpostgrest";
  "server-port" = 3000;
}
