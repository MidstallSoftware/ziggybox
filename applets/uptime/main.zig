const std = @import("std");
const Uptime = @import("Uptime.zig");

pub fn main() !void {
    const value = try Uptime.init();
    const stdout = std.io.getStdOut().writer();

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
