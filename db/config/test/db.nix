{ pkgs }:
let inherit pkgs;
in {
  "host" = "testdb";
  "port" = 5432;
  "user" = "jadbuser";
  "password" = "jadbuserpass";
  "schema" = "jadbschema";
  "database" = "jadb";
  "anonymousRole" = "anonymous";
  "jwtSecret" = "reallyreallyreallyreallyverysafe";
}
