{
  lib,
  stdenv,
  callPackage,
  ziggybox,
  hello,
}:
lib.makeExtensible (final: {
  stdenv = callPackage ./stdenv.nix { inherit ziggybox; };
  hello = hello.override { inherit (final) stdenv; };
})
