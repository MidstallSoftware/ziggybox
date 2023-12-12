const applets = @import("applets");
const builtin = @import("builtin");
const clap = @import("clap");
const options = @import("options");
const std = @import("std");
const ziggybox = @import("ziggybox");

const MainResult = if (builtin.os.tag == .uefi) std.os.uefi.Status else anyerror!void;
const Applet = std.meta.DeclEnum(applets);

fn runApplet(applet: Applet, args: *std.process.ArgIterator) !void {
    inline for (comptime std.meta.declarations(applets), 0..) |decl, i| {
        if (@as(usize, @intFromEnum(applet)) == i) {
            return @field(applets, decl.name).run(args);
        }
    }
    unreachable;
}

pub fn main() MainResult {
    var iter = std.process.ArgIterator.initWithAllocator(ziggybox.common.allocator) catch |err| {
        return if (builtin.os.tag == .uefi) .Aborted else err;
    };
    defer iter.deinit();

    if (options.applet) |applet| {
        _ = iter.next();
        runApplet(applet, &iter) catch |err| {
            return if (builtin.os.tag == .uefi) .Aborted else err;
        };
        if (builtin.os.tag == .uefi) return .Success;
        return;
    }

    const stderr = ziggybox.io.getStdErr();
    const stdout = ziggybox.io.getStdOut();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help    Display this help and exit.
        \\-v, --version Prints the version of ziggybox.
        \\<applet>      The applet to run.
        \\
    );

    if (iter.next()) |execpath| {
        const binname = std.fs.path.stem(execpath);

        if (!std.mem.eql(u8, binname, "ziggybox")) {
            if (std.meta.stringToEnum(Applet, binname)) |applet| {
                runApplet(applet, &iter) catch |err| {
                    return if (builtin.os.tag == .uefi) .Aborted else err;
                };
                if (builtin.os.tag == .uefi) return .Success;
                return;
            } else {
                _ = stderr.print("Applet {s} is not enabled or does not exist.\n", .{binname}) catch {};
                return if (builtin.os.tag == .uefi) .Aborted else error.InvalidApplet;
            }
        }
    }

    var diag = clap.Diagnostic{};
    var res = ziggybox.clap.parse(clap.Help, &params, comptime .{
        .applet = clap.parsers.enumeration(Applet),
    }, .{
        .allocator = ziggybox.common.allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return if (builtin.os.tag == .uefi) .Aborted else err;
    };
    defer res.deinit();

    if (res.args.version != 0) {
        _ = stdout.print("{}\n", .{options.version}) catch {};
        if (builtin.os.tag == .uefi) return .Success;
        return;
    }

    if (res.args.help != 0 or res.positionals.len != 1) {
        clap.help(stdout, clap.Help, &params, .{}) catch |err| {
            return if (builtin.os.tag == .uefi) .Aborted else err;
        };
        if (builtin.os.tag == .uefi) return .Success;
        return;
    }

    runApplet(res.positionals[0], &iter) catch |err| {
        return if (builtin.os.tag == .uefi) .Aborted else err;
    };

    if (builtin.os.tag == .uefi) return .Success;
}
