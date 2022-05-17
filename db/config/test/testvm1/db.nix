{ pkgs }:
let inherit pkgs;
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
