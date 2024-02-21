const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const ziggybox = @import("ziggybox");

fn umount(path: [*:0]const u8) !void {
    const r = std.os.linux.umount(path);
    return switch (std.os.errno(r)) {
        .SUCCESS => {},
        .PERM => error.AccessDenied,
        else => |err| return std.os.unexpectedErrno(err),
    };
}

pub fn run(args: *std.process.ArgIterator) !void {
    const stderr = ziggybox.io.getStdErr();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Display this help and exit.
        \\<path>        The directory to unmount
        \\
    );

    var diag = clap.Diagnostic{};
    var res = ziggybox.clap.parseEx(clap.Help, &params, comptime .{
        .path = clap.parsers.string,
    }, args, .{
        .allocator = ziggybox.common.allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0 or res.positionals.len < 1)
        return clap.help(stderr, clap.Help, &params, .{});

    const path = try ziggybox.common.allocator.dupeZ(u8, res.positionals[0]);
    defer ziggybox.common.allocator.free(path);
    try umount(path);
}
