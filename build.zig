const std = @import("std");
const applets = @import("applets.zig");

fn runAllowFail(b: *std.Build, argv: []const []const u8) ?[]const u8 {
    var c: u8 = 0;
    if (b.runAllowFail(argv, &c, .Ignore) catch null) |result| {
        const end = std.mem.indexOf(u8, result, "\n") orelse result.len;
        return result[0..end];
    }
    return null;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Sets the link mode");
    const applets_list = b.option([]const []const u8, "applets", "List of applets") orelse switch (target.result.os.tag) {
        .linux, .macos => applets.all,
        else => applets.min,
    };

    const version_tag = b.option([]const u8, "version-tag", "Sets the version tag") orelse runAllowFail(b, &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" });
    const build_hash = b.option([]const u8, "build-hash", "Sets the build hash") orelse runAllowFail(b, &.{ "git", "rev-parse", "HEAD" });
    const link_libc = b.option(bool, "link-libc", "Use Zig's stdlib or the C library");
    const strip = b.option(bool, "strip", "Whether to strip the binaries");
    const single_threaded = b.option(bool, "single-threaded", "Whether to only build for single-threaded operations") orelse (optimize == .ReleaseSmall);

    const version = std.SemanticVersion{
        .major = 0,
        .minor = 1,
        .patch = 0,
        .pre = version_tag,
        .build = if (build_hash) |h| h[0..@min(h.len, 7)] else null,
    };

    const options = b.addOptions();
    options.addOption(std.SemanticVersion, "version", version);
    options.addOption([]const []const u8, "applets", applets_list);

    for (applets_list) |applet| {
        const exe = b.addExecutable(.{
            .name = applet,
            .version = version,
            .linkage = linkage,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.pathJoin(&.{ "applets", applet, "main.zig" })),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{
                        .name = "options",
                        .module = options.createModule(),
                    },
                },
                .link_libc = link_libc,
                .strip = strip,
                .single_threaded = single_threaded,
            }),
        });
        b.installArtifact(exe);
    }
}
