const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(std.Build.Step.Compile.Linkage, "linkage", "Sets the link mode") orelse .static;

    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });

    const exec = b.addExecutable(.{
        .name = "ziggybox",
        .root_source_file = .{ .path = b.pathFromRoot("src/ziggybox.zig") },
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .link_libc = linkage == .dynamic,
    });

    exec.addModule("clap", clap.module("clap"));
    b.installArtifact(exec);
}
