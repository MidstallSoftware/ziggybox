const builtin = @import("builtin");
const std = @import("std");
const version = builtin.os.version_range.linux;

pub const Sysinfo = if ((builtin.cpu.arch == .x86 and version.isAtLeast(.{ .major = 2, .minor = 3, .patch = 23 }).?) or version.isAtLeast(.{ .major = 2, .minor = 3, .patch = 48 }).?)
    extern struct {
        uptime: c_long,
        loads: [3]c_ulong,
        total_ram: c_ulong,
        free_ram: c_ulong,
        shared_ram: c_ulong,
        buffered_ram: c_ulong,
        total_swap: c_ulong,
        free_swap: c_ulong,
        procs: c_ushort,
        total_high: c_ulong,
        free_high: c_ulong,
        mem_unit: c_uint,
        padding: [20 - 2 * @sizeOf(c_long) - @sizeOf(c_int)]c_char,
    }
else
    extern struct {
        uptime: c_long,
        loads: [3]c_ulong,
        total_ram: c_ulong,
        free_ram: c_ulong,
        shared_ram: c_ulong,
        buffered_ram: c_ulong,
        total_swap: c_ulong,
        free_swap: c_ulong,
        procs: c_ushort,
        padding: [22]c_char,
    };

pub usingnamespace if (builtin.link_libc) struct {
    pub extern "C" fn sysinfo(value: *Sysinfo) c_int;
} else struct {
    pub fn sysinfo(value: *Sysinfo) usize {
        return std.os.linux.syscall1(.sysinfo, @intFromPtr(value));
    }
};
