{
  lib,
  zig,
  src,
  system,
  callPackage,
}:
lib.makeExtensible (
  finalAttrs:
  let
    drv = derivation {
      pname = "ziggybox";
      version = "0.1.0-git";
      name = "${finalAttrs.pname}-${finalAttrs.version}";

      inherit src system;

      builder = lib.getExe zig;
      realBuilder = lib.getExe zig;

      outputs = [
        "out"
        "cache"
      ];

      args = [
        "build"
        "--build-file"
        "${finalAttrs.src}/build.zig"
        "--global-cache-dir"
        "${placeholder "cache"}"
        "--cache-dir"
        "${placeholder "cache"}"
        "--prefix"
        "${placeholder "out"}"
        "--release=small"
        "-Dcpu=baseline"
        "-Dtarget=${system}-musl"
        "-Dstrip"
      ];
    };

    passthru = {
      tests = callPackage ./tests {
        ziggybox = drv;
      };
    };
  in
  drv
  // passthru
  // {
    inherit passthru;
  }
)
