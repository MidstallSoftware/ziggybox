const std = @import("std");

fn formatSecondsSinceEpoch(writer: anytype, timestamp: i64) !void {
    try writer.print("{}", .{timestamp});
}

pub const s = formatSecondsSinceEpoch;
