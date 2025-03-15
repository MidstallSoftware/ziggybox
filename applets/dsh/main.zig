const builtin = @import("builtin");
const std = @import("std");
const native_os = builtin.os.tag;

fn splitArgs(gpa: std.mem.Allocator, line: []const u8) ![]const []const u8 {
    var args = std.ArrayList([]const u8).init(gpa);
    defer args.deinit();

    var i: usize = 0;
    var x: usize = 0;
    while (i < line.len) : (i += 1) {
        if (line[i] == ' ' and i > 0) {
            try args.append(line[x..i]);
            x = i + 1;
        } else if (line[i] == '"') {
            const end = std.mem.indexOf(u8, line[(i + 1)..], "\"") orelse line.len;
            try args.append(line[(i + 1)..end]);
            x += end;
        }
    }

    if (args.items.len == 0) {
        try args.append(line);
    } else {
        try args.append(line[x..]);
    }

    return try args.toOwnedSlice();
}

fn isSuperUser() bool {
    return switch (native_os) {
        .linux => std.os.linux.geteuid() == 0,
        else => false,
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

    const shexec = args.next() orelse unreachable;

    const stdout = std.io.getStdOut().writer().any();
    const stderr = std.io.getStdErr().writer().any();
    const stdin = std.io.getStdIn().reader().any();

    var env_map = try std.process.getEnvMap(gpa);
    defer env_map.deinit();

    try env_map.put("0", shexec);
    try env_map.put("SHELL", shexec);

    var line = std.ArrayList(u8).init(gpa);

    while (true) {
        try stdout.writeByte(if (isSuperUser()) '#' else '$');
        try stdout.writeByte(' ');

        line.clearAndFree();
        stdin.streamUntilDelimiter(line.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => {
                try stdout.writeByte('\n');
                break;
            },
            else => return err,
        };

        const argv = try splitArgs(gpa, line.items);
        defer gpa.free(argv);

        var proc = std.process.Child.init(argv, gpa);

        proc.env_map = &env_map;

        proc.stdout_behavior = .Inherit;
        proc.stderr_behavior = .Inherit;
        proc.stdin_behavior = .Inherit;

        _ = proc.spawnAndWait() catch |err| try stderr.print("dsh: failed to execute {s}: {}\n", .{ argv[0], err });

        try stdout.writeByte('\n');
    }
}
