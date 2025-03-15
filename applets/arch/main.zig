const builtin = @import("builtin");
const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer().any();
    try stdout.writeAll(@tagName(builtin.cpu.arch) ++ "\n");
}
