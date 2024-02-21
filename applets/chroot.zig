const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const ziggybox = @import("ziggybox");

fn chroot(path: [*:0]const u8) !void {
    const r = std.os.linux.chroot(path);
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
        \\<path>        The directory to chroot into.
        \\<str>...      The command to execute.
        \\
    );

    var diag = clap.Diagnostic{};
    var res = ziggybox.clap.parseEx(clap.Help, &params, comptime .{
        .path = clap.parsers.string,
        .str = clap.parsers.string,
    }, args, .{
        .allocator = ziggybox.common.allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0 or res.positionals.len < 2)
        return clap.help(stderr, clap.Help, &params, .{});

    const path = try ziggybox.common.allocator.dupeZ(u8, res.positionals[0]);
    defer ziggybox.common.allocator.free(path);
    try chroot(path);

    var proc = std.ChildProcess.init(res.positionals[1..], ziggybox.common.allocator);
    proc.stdin_behavior = .Inherit;
    proc.stdout_behavior = .Inherit;
    proc.stderr_behavior = .Inherit;
    _ = try proc.spawnAndWait();
}
