const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const ziggybox = @import("ziggybox");

pub fn run(args: *std.process.ArgIterator) !void {
    const stderr = ziggybox.io.getStdErr();
    const stdout = ziggybox.io.getStdOut();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Display this help and exit.
        \\<file>...    The file or files to list 
        \\
    );

    var diag = clap.Diagnostic{};
    var res = ziggybox.clap.parseEx(clap.Help, &params, comptime .{
        .file = clap.parsers.string,
    }, args, .{
        .allocator = ziggybox.common.allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(stderr, clap.Help, &params, .{});

    if (res.positionals.len == 0) {
        const stdin = ziggybox.io.getStdIn();

        while (stdin.readUntilDelimiterAlloc(ziggybox.common.allocator, '\n', 1000) catch null) |line| {
            defer ziggybox.common.allocator.free(line);
            stdout.writeAll(line) catch break;
            stdout.writeByte('\n') catch break;
        }
    } else {
        for (res.positionals) |positional| {
            const path = if (std.fs.path.isAbsolute(positional)) try ziggybox.common.allocator.dupe(u8, positional) else blk: {
                const cwd = try std.process.getCwdAlloc(ziggybox.common.allocator);
                defer ziggybox.common.allocator.free(cwd);
                break :blk try std.fs.path.join(ziggybox.common.allocator, &.{
                    cwd,
                    positional,
                });
            };
            defer ziggybox.common.allocator.free(path);

            var file = try std.fs.openFileAbsolute(path, .{});
            defer file.close();
            while (true) {
                try stdout.writeByte(file.reader().readByte() catch break);
            }
        }
    }
}
