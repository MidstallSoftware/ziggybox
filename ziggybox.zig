const applets = @import("applets");
const builtin = @import("builtin");
const clap = @import("clap");
const options = @import("options");
const std = @import("std");
const ziggybox = @import("ziggybox");

const MainResult = if (builtin.os.tag == .uefi) std.os.uefi.Status else anyerror!void;
const Applet = std.meta.DeclEnum(applets);

pub const std_options = struct {
    pub const logFn = log;
};

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = ziggybox.io.getStdErr();
    nosuspend stderr.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
}

fn runApplet(applet: Applet, args: *std.process.ArgIterator) !void {
    inline for (comptime std.meta.declarations(applets), 0..) |decl, i| {
        if (@as(usize, @intFromEnum(applet)) == i) {
            return @field(applets, decl.name).run(args);
        }
    }
    unreachable;
}

fn dumpStackTrace(stack_trace: std.builtin.StackTrace) void {
    nosuspend {
        if (comptime builtin.target.isWasm()) {
            if (builtin.os.tag == .wasi) {
                const stderr = ziggybox.io.getStdErr();
                stderr.print("Unable to dump stack trace: not implemented for Wasm\n", .{}) catch return;
            }
            return;
        }
        const stderr = ziggybox.io.getStdErr();
        if (builtin.strip_debug_info) {
            stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
            return;
        }
        const debug_info = std.debug.getSelfDebugInfo() catch |err| {
            stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
        std.debug.writeStackTrace(stack_trace, stderr, ziggybox.common.allocator, debug_info, .escape_codes) catch |err| {
            stderr.print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
    }
}

fn realMain() !void {
    var iter = try std.process.ArgIterator.initWithAllocator(ziggybox.common.allocator);
    defer iter.deinit();

    if (options.applet) |applet| {
        _ = iter.next();
        return try runApplet(applet, &iter);
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
                return try runApplet(applet, &iter);
            } else {
                _ = stderr.print("Applet {s} is not enabled or does not exist.\n", .{binname}) catch {};
                return error.InvalidApplet;
            }
        }
    }

    var diag = clap.Diagnostic{};
    var res = ziggybox.clap.parse(clap.Help, &params, comptime .{
        .applet = clap.parsers.enumeration(Applet),
    }, .{
        .allocator = ziggybox.common.allocator,
        .limit = true,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.version != 0) {
        return try stdout.print("{}\n", .{options.version});
    }

    if (res.args.help != 0 or res.positionals.len != 1) {
        return clap.help(stdout, clap.Help, &params, .{});
    }

    try runApplet(res.positionals[0], &iter);
}

pub fn main() MainResult {
    realMain() catch |err| {
        if (builtin.os.tag == .uefi) {
            std.log.err("{s}", .{@errorName(err)});
            return .Aborted;
        }
        return err;
    };

    if (builtin.os.tag == .uefi) return .Success;
}
