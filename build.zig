const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(std.Build.Step.Compile.Linkage, "linkage", "Sets the link mode") orelse .static;
    const applets = b.option([]const []const u8, "applets", "List of applets") orelse &[_][]const u8{
        "arch",
        "uptime",
    };

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });

    var appletsImports = std.ArrayList(u8).init(b.allocator);
    errdefer appletsImports.deinit();

    for (applets) |prog| {
        try appletsImports.writer().print(
            \\pub const {s} = @import("{s}.zig");
            \\
        , .{
            prog,
            b.pathFromRoot(b.pathJoin(&.{ "src", "applets", prog })),
        });
    }

    const writeFiles = b.addWriteFiles();

    const options = b.addOptions();

    const exec = b.addExecutable(.{
        .name = "ziggybox",
        .root_source_file = .{ .path = b.pathFromRoot("src/ziggybox.zig") },
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .link_libc = linkage == .dynamic,
    });

    exec.addModule("applets", b.createModule(.{
        .source_file = writeFiles.add("applet-imports.zig", appletsImports.items),
    }));
    exec.addModule("clap", clap.module("clap"));
    exec.addModule("options", options.createModule());
    b.installArtifact(exec);
}
