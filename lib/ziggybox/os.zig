const builtin = @import("builtin");
const std = @import("std");

pub const linux = @import("os/linux.zig");
pub const windows = @import("os/windows.zig");
pub const uefi = @import("os/uefi.zig");

pub inline fn time() !std.time.epoch.EpochSeconds {
    if (builtin.os.tag == .uefi) {
        var value: std.os.uefi.Time = undefined;
        try std.os.uefi.system_table.runtime_services.getTime(&value, null).err();
        return .{ .secs = uefi.epochFromTime(value) };
    }

    return .{
        .secs = std.math.lossyCast(u64, std.time.timestamp()),
    };
}
