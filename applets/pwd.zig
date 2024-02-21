const builtin = @import("builtin");
const std = @import("std");
const ziggybox = @import("ziggybox");

pub fn run(_: *std.process.ArgIterator) !void {
    const str = try std.process.getCwdAlloc(ziggybox.common.allocator);
    defer ziggybox.common.allocator.free(str);
    return ziggybox.io.getStdOut().print("{s}\n", .{str});
}
