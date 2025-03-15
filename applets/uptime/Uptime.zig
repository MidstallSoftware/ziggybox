const builtin = @import("builtin");
const std = @import("std");
const linux = @import("linux.zig");
const windows = @import("windows.zig");
const Uptime = @This();

time: std.time.epoch.EpochSeconds,
uptime: std.time.epoch.EpochSeconds,
users: usize = 0,
loads: [3]f32,

inline fn load(value: c_ulong) f32 {
    const fshift: u8 = 16;
    const fixed1: u17 = 65536;
    const loadInt = value >> fshift;
    const loadFrac = ((value & (fixed1 - 1)) * 100) >> fshift;
    return std.math.lossyCast(f32, loadInt) + (std.math.lossyCast(f32, loadFrac) / @as(f32, 100.0));
}

pub fn init() !Uptime {
    return switch (builtin.os.tag) {
        .linux => blk: {
            var sysinfo: linux.Sysinfo = undefined;
            switch (std.posix.errno(linux.sysinfo(&sysinfo))) {
                .SUCCESS => {},
                .FAULT => unreachable,
                else => |err| return std.posix.unexpectedErrno(err),
            }

            const time = std.time.epoch.EpochSeconds{
                .secs = std.math.lossyCast(u64, std.time.timestamp()),
            };

            const uptime = std.time.epoch.EpochSeconds{
                .secs = std.math.lossyCast(u64, sysinfo.uptime),
            };

            break :blk .{
                .time = time,
                .uptime = uptime,
                .loads = [3]f32{
                    load(sysinfo.loads[0]),
                    load(sysinfo.loads[1]),
                    load(sysinfo.loads[2]),
                },
            };
        },
        .windows => .{
            .time = .{
                .secs = std.math.lossyCast(u64, std.time.timestamp()),
            },
            .uptime = .{
                .secs = std.math.lossyCast(u64, windows.GetTickCount64() / std.time.ms_per_s),
            },
            .loads = [3]f32{ 0, 0, 0 },
        },
        else => .{
            .time = .{
                .secs = std.math.lossyCast(u64, std.time.timestamp()),
            },
            .uptime = .{ .secs = 0 },
            .loads = [3]f32{ 0, 0, 0 },
        },
    };
}
