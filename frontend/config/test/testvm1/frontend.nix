{ pkgs, lib, config, ... }:
let inherit pkgs lib config;
in { "backendServer" = "testvm1"; }
