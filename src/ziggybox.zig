const builtin = @import("builtin");
const clap = @import("clap");
const std = @import("std");
const clapExt = @import("clap.zig");
const common = @import("common.zig");
const io = @import("io.zig");

const MainResult = if (builtin.os.tag == .uefi) std.os.uefi.Status else anyerror!void;
const Applet = std.meta.DeclEnum(@import("applets"));

pub fn main() MainResult {
    const stderr = io.getStdErr();
    const stdout = io.getStdOut();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help  Display this help and exit.
        \\<applet>    The applet to run.
        \\
    );

    if (builtin.os.tag == .uefi) {
        var protocol: ?*std.os.uefi.protocol.LoadedImage = undefined;
        const status = std.os.uefi.system_table.boot_services.?.locateProtocol(&std.os.uefi.protocol.LoadedImage.guid, null, @as(*?*anyopaque, @ptrCast(&protocol)));
        if (status != .Success) return status;

        if (protocol) |proto| {
            _ = proto;
        }
    }

    var iter = try std.process.ArgIterator.initWithAllocator(common.allocator);
    defer iter.deinit();

    if (iter.next()) |execpath| {
        const binname = std.fs.path.basename(execpath);

        if (!std.mem.eql(u8, binname, "ziggybox")) {
            _ = stderr.print("Alias via symlink is not yet implemented\n", .{}) catch {};
            return if (builtin.os.tag == .uefi) .Aborted else error.NotImplemented;
        }
    }

    var diag = clap.Diagnostic{};
    var res = clapExt.parse(clap.Help, &params, comptime .{
        .applet = clap.parsers.enumeration(Applet),
    }, .{
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
