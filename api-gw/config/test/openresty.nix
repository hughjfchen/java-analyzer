{ pkgs, lib, config, ... }:
let inherit pkgs lib config;
in { "docRoot" = "/var/${config.userName}/openresty/nginx/web"; }
