{ pkgs, lib, config, ... }:
let inherit pkgs lib config;
in {
  "host" = "testvm1";
  "port" = 5432;
  "user" = "jadbuser";
  "password" = "jadbuserpass";
  "schema" = "jadbschema";
  "database" = "jadb";
  "anonymousRole" = "anonymous";
  "jwtSecret" = "reallyreallyreallyreallyverysafe";
}
