const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const common = @import("common.zig");
const io = @import("io.zig");

const MainResult = if (builtin.os.tag == .uefi) std.os.uefi.Status else anyerror!void;

pub fn main() MainResult {
    const stderr = io.getStdErr();
    const stdout = io.getStdOut();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help  Display this help and exit.
        \\<str>       The name of the program.
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .allocator = common.allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return if (builtin.os.tag == .uefi) .Aborted else err;
    };
    defer res.deinit();

    if (res.args.help != 0 or res.positionals.len != 1) {
        clap.help(stdout, clap.Help, &params, .{}) catch |err| {
            return if (builtin.os.tag == .uefi) .Aborted else err;
        };
        if (builtin.os.tag == .uefi) return .Success;
        return;
    }

    if (builtin.os.tag == .uefi) return .Success;
}
