{
  lib,
  stdenv,
  zig,
  src,
  callPackage,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ziggybox";
  version = "0.1.0-git";

  inherit src;

  nativeBuildInputs = [
    zig.hook
  ];

  passthru = {
    bootstrap = callPackage ./bootstrap.nix {
      inherit lib zig src;
      inherit (stdenv.hostPlatform) system;
    };

    tests = callPackage ./tests {
      ziggybox = finalAttrs.finalPackage;
    };
  };
})
