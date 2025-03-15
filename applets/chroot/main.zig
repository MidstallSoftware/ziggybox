const builtin = @import("builtin");
const std = @import("std");
const native_os = builtin.os.tag;

fn chroot(path: [*:0]const u8) !void {
    const r = std.os.linux.chroot(path);
    return switch (std.posix.errno(r)) {
        .SUCCESS => {},
        .NOENT => error.FileNotFound,
        .NOTDIR => error.NotDirectory,
        .PERM => error.AccessDenied,
        else => |err| return std.posix.unexpectedErrno(err),
    };
}

var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const gpa_deinit = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        if (builtin.single_threaded) break :gpa .{ arena_allocator.allocator(), true };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (gpa_deinit) {
        _ = debug_allocator.deinit();
    };

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    _ = args.skip();

    const path = args.next() orelse return error.MissingArgument;

    var cargs = std.ArrayList([]const u8).init(gpa);
    defer cargs.deinit();

    while (args.next()) |a| try cargs.append(a);

    try chroot(path);

    var proc = std.process.Child.init(cargs.items, gpa);
    proc.stdin_behavior = .Inherit;
    proc.stdout_behavior = .Inherit;
    proc.stderr_behavior = .Inherit;
    _ = try proc.spawnAndWait();
}
