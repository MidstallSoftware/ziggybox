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
        "cal",
        "cat",
        "chroot",
        "false",
        "pwd",
        "true",
        "umount",
        "uptime",
        "yes",
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
        .root_source_file = .{ .path = b.pathFromRoot("lib/ziggybox.zig") },
        .imports = &.{
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
        .root_source_file = writeFiles.add("applet-imports.zig", appletsImports.items),
        .imports = &.{
            .{
                .name = "ziggybox-applets",
                .module = b.createModule(.{
                    .root_source_file = .{ .path = b.pathFromRoot("applets.zig") },
                    .imports = &.{
                        .{
                            .name = "clap",
                            .module = clap.module("clap"),
                        },
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
        .root_source_file = options.getOutput(),
        .imports = &.{
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
        exec.build_id = std.zig.BuildId.initHexString(h[0..@min(h.len, 32)]);
    }

    exec.root_module.addImport("applets", applets);
    exec.root_module.addImport("clap", clap.module("clap"));
    exec.root_module.addImport("options", optionsModule);
    exec.root_module.addImport("ziggybox", ziggybox);
    b.installArtifact(exec);

    for (appletsList) |applet| {
        const appletOptions = b.addOptions();
        try appletOptions.contents.appendSlice(options.contents.items);

        try appletOptions.contents.writer().print(
            \\pub const applet: ?std.meta.DeclEnum(@import("applets")) = .{s};
        , .{applet});

        const appletOptionsModule = b.createModule(.{
            .root_source_file = appletOptions.getOutput(),
            .imports = &.{
                .{
                    .name = "applets",
                    .module = applets,
                },
            },
        });

        const appletExec = b.addExecutable(.{
            .name = applet,
            .root_source_file = exec.root_module.root_source_file,
            .target = target,
            .optimize = optimize,
            .linkage = linkage,
            .link_libc = linkage == .dynamic,
            .version = version,
        });

        if (buildHash) |h| {
            appletExec.build_id = std.zig.BuildId.initHexString(h[0..@min(h.len, 32)]);
        }

        appletExec.root_module.addImport("applets", applets);
        appletExec.root_module.addImport("clap", clap.module("clap"));
        appletExec.root_module.addImport("options", appletOptionsModule);
        appletExec.root_module.addImport("ziggybox", ziggybox);
        b.installArtifact(appletExec);
    }

    try options.contents.writer().print(
        \\pub const applet: ?std.meta.DeclEnum(@import("applets")) = null;
    , .{});
}
