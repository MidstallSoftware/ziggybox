{
  lib,
  config,
  path,
  system,
  buildPlatform,
  hostPlatform,
  targetPlatform,
  fetchurl,
  bash,
  ziggybox,
  gnumake,
}:
import "${path}/pkgs/stdenv/generic/default.nix" {
  name = "stdenv-test";
  cc = null;
  shell = lib.getExe bash;
  initialPath = [ ziggybox gnumake ];
  fetchurlBoot = fetchurl;
  inherit
    config
    buildPlatform
    hostPlatform
    targetPlatform
    ;
}
