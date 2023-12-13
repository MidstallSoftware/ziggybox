const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const ziggybox = @import("ziggybox");

const math = struct {
    pub const weekLen = 20;
    pub const headSep = 2;
    pub const jWeekLen = weekLen + 7;

    pub inline fn headerText(isJulian: bool) usize {
        const base = (weekLen * 3) + (headSep * 2);
        if (isJulian) {
            const julian = (jWeekLen * 2) - ((weekLen * 3) + (headSep * 2));
            return base + julian;
        }
        return base;
    }

    pub inline fn calcWeekLen(isJulian: bool) usize {
        if (isJulian) return weekLen + (jWeekLen - weekLen);
        return weekLen;
    }
};

const MonthAndYear = struct {
    month: u4,
    year: u16,

    pub fn setMonth(self: *MonthAndYear, value: u16) !void {
        if (value < 1 or value > 12) {
            try ziggybox.io.getStdErr().print("calc: number {} is not in 1..12 range\n", .{value});
            return error.OutOfRange;
        }

        self.month = @intCast(value);
    }

    pub fn setYear(self: *MonthAndYear, value: u16) !void {
        if (value < 1 or value > 9999) {
            try ziggybox.io.getStdErr().print("calc: number {} is not in 1..9999 range\n", .{value});
            return error.OutOfRange;
        }

        self.year = @intCast(value);
    }
};

inline fn monthName(month: std.time.epoch.Month) []const u8 {
    return switch (month) {
        .jan => "January",
        .feb => "February",
        .mar => "March",
        .apr => "April",
        .may => "May",
        .jun => "June",
        .jul => "July",
        .aug => "August",
        .sep => "September",
        .oct => "October",
        .nov => "November",
        .dec => "December",
    };
}

fn pad(len: usize, writer: anytype) !void {
    var i: usize = 0;
    while (i < len) : (i += 1) try writer.writeByte(' ');
}

fn center(str: []const u8, len: usize, sep: usize, writer: anytype) !void {
    const n = str.len;
    const nlen = len - n;

    try pad((nlen / 2) + n, writer);
    try writer.writeAll(str);
    try pad((nlen / 2) + (nlen % 2) + sep, writer);
}

fn fmtCenter(comptime fmt: []const u8, args: anytype, len: usize, sep: usize, writer: anytype) !void {
    const str = try std.fmt.allocPrint(ziggybox.common.allocator, fmt, args);
    defer ziggybox.common.allocator.free(str);
    return try center(str, len, sep, writer);
}

pub fn run(args: *std.process.ArgIterator) !void {
    const stderr = ziggybox.io.getStdErr();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Display this help and exit.
        \\-j, --julian  Use the Julian calendar.
        \\-m, --monday  Weeks start on Monday.
        \\-y, --year    Displays the entire year.
        \\<month>       Month
        \\<year>        Year
        \\
    );

    var diag = clap.Diagnostic{};
    var res = ziggybox.clap.parseEx(clap.Help, &params, comptime .{
        .month = clap.parsers.int(u16, 0),
        .year = clap.parsers.int(u16, 0),
    }, args, .{
        .allocator = ziggybox.common.allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0 or res.positionals.len > 2)
        return clap.help(stderr, clap.Help, &params, .{});

    var value = MonthAndYear{ .month = 1, .year = 0 };
    var isMonthSet = false;
    var isYearSet = false;

    if (res.positionals.len == 1) {
        try value.setYear(res.positionals[0]);
        isYearSet = true;
    }

    if (res.positionals.len == 2) {
        try value.setMonth(res.positionals[0]);
        try value.setYear(res.positionals[1]);

        isYearSet = true;
        isMonthSet = true;
    }

    if (!isYearSet and !isMonthSet) {
        const time = try ziggybox.os.time();
        value.year = time.getEpochDay().calculateYearDay().year;
        value.month = @as(u4, @intFromEnum(time.getEpochDay().calculateYearDay().calculateMonthDay().month));
    }

    const stdout = ziggybox.io.getStdOut();
    const julian = @min(res.args.julian, 1);

    if (res.args.year > 0) {
        try fmtCenter("{}", .{value.year}, math.headerText(julian > 0), 0, stdout);
        try stdout.writeAll("\n\n");

        const weekLen = math.calcWeekLen(julian > 0);
        var month: u4 = 0;
        while (month < 12) : (month += (3 - @as(u4, @intCast(julian)))) {
            try fmtCenter("{s}", .{monthName(@enumFromInt(month + 1))}, weekLen, math.headSep, stdout);

            if (julian == 0) {
                try fmtCenter("{s}", .{monthName(@enumFromInt(month + 2))}, weekLen, math.headSep, stdout);
            }

            try fmtCenter("{s}", .{monthName(@enumFromInt(month + 3 - @as(u4, @intCast(julian))))}, weekLen, 0, stdout);
            try stdout.writeByte('\n');
        }
    }
}
