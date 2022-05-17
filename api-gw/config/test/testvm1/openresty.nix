{ pkgs }:
let inherit pkgs;
in { "docRoot" = "/var/${pkgs.userName}/openresty/nginx/web"; }
