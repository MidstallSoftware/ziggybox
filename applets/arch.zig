const builtin = @import("builtin");
const std = @import("std");
const ziggybox = @import("ziggybox");

pub fn run(_: *std.process.ArgIterator) !void {
    return ziggybox.io.getStdOut().print("{s}\n", .{@tagName(builtin.cpu.arch)});
}
