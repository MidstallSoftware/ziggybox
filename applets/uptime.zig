const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const ziggybox = @import("ziggybox");

inline fn load(value: c_ulong) f32 {
    const fshift: u8 = 16;
    const fixed1: u17 = 65536;
    const loadInt = value >> fshift;
    const loadFrac = ((value & (fixed1 - 1)) * 100) >> fshift;
    return std.math.lossyCast(f32, loadInt) + (std.math.lossyCast(f32, loadFrac) / @as(f32, 100.0));
}

const Uptime = struct {
    time: std.time.epoch.EpochSeconds,
    uptime: std.time.epoch.EpochSeconds,
    users: usize = 0,
    loads: [3]f32,

    pub fn init() !Uptime {
        return switch (builtin.os.tag) {
            .linux => blk: {
                var sysinfo: ziggybox.os.linux.Sysinfo = undefined;
                switch (if (builtin.link_libc) std.c.getErrno(ziggybox.os.linux.sysinfo(&sysinfo)) else std.os.errno(ziggybox.os.linux.sysinfo(&sysinfo))) {
                    .SUCCESS => {},
                    .FAULT => unreachable,
                    else => |err| return std.os.unexpectedErrno(err),
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
                    .secs = std.math.lossyCast(u64, ziggybox.os.windows.GetTickCount64() / std.time.ms_per_s),
                },
                .loads = [3]f32{ 0, 0, 0 },
            },
            .uefi => blk: {
                var time: std.os.uefi.Time = undefined;
                try std.os.uefi.system_table.runtime_services.getTime(&time, null).err();

                break :blk .{
                    .time = .{
                        .secs = ziggybox.os.uefi.epochFromTime(time),
                    },
                    .uptime = .{ .secs = 0 },
                    .loads = [3]f32{ 0, 0, 0 },
                };
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
};

pub fn run(_: *std.process.ArgIterator) !void {
    const value = try Uptime.init();
    const stdout = ziggybox.io.getStdOut();

    try stdout.print(" {d:0>2}:{d:0>2}:{d:0>2} up ", .{
        value.time.getDaySeconds().getHoursIntoDay(),
        value.time.getDaySeconds().getMinutesIntoHour(),
        value.time.secs % 60,
    });

    const updays = value.uptime.getEpochDay().day;
    if (updays > 0) {
        try stdout.print("{} day", .{updays});
        if (updays > 1) try stdout.writeByte('s');
        try stdout.writeAll(", ");
    }

    const uphours = value.uptime.getDaySeconds().getHoursIntoDay();
    const upminutes = value.uptime.getDaySeconds().getMinutesIntoHour();
    if (uphours > 0) {
        try stdout.print("{}:{}", .{ uphours, upminutes });
    } else {
        try stdout.print("{} min", .{upminutes});
    }

    if (value.users > 0) {
        try stdout.print(",  {} users", .{value.users});
    }

    try stdout.print(",  load average: {d:.2}, {d:.2}, {d:.2}\n", .{
        value.loads[0],
        value.loads[1],
        value.loads[2],
    });
}
