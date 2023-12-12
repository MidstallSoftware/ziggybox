const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const ziggybox = @import("ziggybox");

pub fn run(args: *std.process.ArgIterator) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Display this help and exit.
        \\<str>...
        \\
    );

    var diag = clap.Diagnostic{};
    var res = ziggybox.clap.parseEx(clap.Help, &params, clap.parsers.default, args, .{
        .allocator = ziggybox.common.allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(ziggybox.io.getStdErr(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(ziggybox.io.getStdErr(), clap.Help, &params, .{});

    const str = try (if (res.positionals.len > 0) std.mem.join(ziggybox.common.allocator, " ", res.positionals) else ziggybox.common.allocator.dupe(u8, "y"));
    defer ziggybox.common.allocator.free(str);

    while (true) try ziggybox.io.getStdOut().print("{s}\n", .{str});
}
