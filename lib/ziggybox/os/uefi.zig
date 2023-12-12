const std = @import("std");

fn daysInYear(year: u16, maxMonth: u4) u32 {
    const leapYear: std.time.epoch.YearLeapKind = if (std.time.epoch.isLeapYear(year)) .leap else .not_leap;
    var days: u32 = 0;
    var month: u4 = 0;
    while (month < maxMonth) : (month += 1) {
        days += std.time.epoch.getDaysInMonth(leapYear, @enumFromInt(month + 1));
    }
    return days;
}

pub fn epochFromTime(time: std.os.uefi.Time) u64 {
    var year: u16 = 0;
    var days: u32 = 0;

    while (year < (time.year - 1971)) : (year += 1) {
        days += daysInYear(year + 1970, 12);
    }

    days += daysInYear(time.year, @as(u4, @intCast(time.month)) - 1) + time.day;
    const hours = time.hour + (days * 24);
    const minutes = time.minute + (hours * 60);
    return time.second + (minutes * 60);
}
