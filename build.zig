const std = @import("std");

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

    const linkage = b.option(std.Build.Step.Compile.Linkage, "linkage", "Sets the link mode") orelse .static;
    const appletsList = b.option([]const []const u8, "applets", "List of applets") orelse &[_][]const u8{
        "arch",
        "uptime",
    };

    const versionTag = b.option([]const u8, "version-tag", "Sets the version tag") orelse runAllowFail(b, &.{ "git", "rev-parse", "--abbrev-ref", "HEAD" });
    const buildHash = b.option([]const u8, "build-hash", "Sets the build hash") orelse runAllowFail(b, &.{ "git", "rev-parse", "HEAD" });

    const version = std.SemanticVersion{
        .major = 0,
        .minor = 1,
        .patch = 0,
        .pre = versionTag,
        .build = if (buildHash) |h| h[0..@min(h.len, 7)] else null,
    };

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });

    const ziggybox = b.createModule(.{
        .source_file = .{ .path = b.pathFromRoot("lib/ziggybox.zig") },
        .dependencies = &.{
            .{
                .name = "clap",
                .module = clap.module("clap"),
            },
        },
    });

    var appletsImports = std.ArrayList(u8).init(b.allocator);
    errdefer appletsImports.deinit();

    for (appletsList) |applet| {
        try appletsImports.writer().print(
            \\pub const @"{s}" = @import("ziggybox-applets").@"{s}";
            \\
        , .{ applet, applet });
    }

    const writeFiles = b.addWriteFiles();

    const applets = b.createModule(.{
        .source_file = writeFiles.add("applet-imports.zig", appletsImports.items),
        .dependencies = &.{
            .{
                .name = "ziggybox-applets",
                .module = b.createModule(.{
                    .source_file = .{ .path = b.pathFromRoot("applets.zig") },
                    .dependencies = &.{
                        .{
                            .name = "ziggybox",
                            .module = ziggybox,
                        },
                    },
                }),
            },
        },
    });

    const options = b.addOptions();
    try options.contents.writer().print(
        \\const std = @import("std");
        \\pub const version = std.SemanticVersion.parse("{}") catch |err| @compileError(@errorName(err));
        \\
    , .{version});

    const optionsModule = b.createModule(.{
        .source_file = options.getOutput(),
        .dependencies = &.{
            .{
                .name = "applets",
                .module = applets,
            },
        },
    });

    const exec = b.addExecutable(.{
        .name = "ziggybox",
        .root_source_file = .{ .path = b.pathFromRoot("ziggybox.zig") },
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .link_libc = linkage == .dynamic,
        .version = version,
    });

    if (buildHash) |h| {
        exec.build_id = std.Build.Step.Compile.BuildId.initHexString(h[0..@min(h.len, 32)]);
    }

    exec.addModule("applets", applets);
    exec.addModule("clap", clap.module("clap"));
    exec.addModule("options", optionsModule);
    exec.addModule("ziggybox", ziggybox);
    b.installArtifact(exec);

    for (appletsList) |applet| {
        const appletOptions = b.addOptions();
        try appletOptions.contents.appendSlice(options.contents.items);

        try appletOptions.contents.writer().print(
            \\pub const applet: ?std.meta.DeclEnum(@import("applets")) = .{s};
        , .{applet});

        const appletOptionsModule = b.createModule(.{
            .source_file = appletOptions.getOutput(),
            .dependencies = &.{
                .{
                    .name = "applets",
                    .module = applets,
                },
            },
        });

        const appletExec = b.addExecutable(.{
            .name = applet,
            .root_source_file = exec.root_src,
            .target = target,
            .optimize = optimize,
            .linkage = linkage,
            .link_libc = linkage == .dynamic,
            .version = version,
        });

        if (buildHash) |h| {
            appletExec.build_id = std.Build.Step.Compile.BuildId.initHexString(h[0..@min(h.len, 32)]);
        }

        appletExec.addModule("applets", applets);
        appletExec.addModule("clap", clap.module("clap"));
        appletExec.addModule("options", appletOptionsModule);
        appletExec.addModule("ziggybox", ziggybox);
        b.installArtifact(appletExec);
    }

    try options.contents.writer().print(
        \\pub const applet: ?std.meta.DeclEnum(@import("applets")) = null;
    , .{});
}
