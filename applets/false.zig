const builtin = @import("builtin");
const std = @import("std");
const ziggybox = @import("ziggybox");

pub fn run(_: *std.process.ArgIterator) !void {
    std.os.exit(1);
}
