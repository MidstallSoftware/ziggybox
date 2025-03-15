const builtin = @import("builtin");
const std = @import("std");
const native_os = builtin.os.tag;

fn indexOfCount(comptime T: type, haystack: []const T, max: usize, needle: []const T) ?usize {
    var i: usize = 0;
    var x: usize = 0;

    while (i < haystack.len) : (i += 1) {
        if (x == max) return i;

        i += std.mem.indexOfPos(T, haystack, i, needle) orelse return null;
        x += 1;
    }
    return null;
}

fn head(bytes: ?isize, lines: isize, delim: []const u8, source_file: std.fs.File, gpa: std.mem.Allocator) !void {
    const source = try source_file.readToEndAlloc(gpa, std.math.maxInt(usize));
    defer gpa.free(source);

    var stdout = std.io.getStdOut();
    if (bytes) |b| {
        const byte_pos = if (b < 0) source.len - @abs(b) else @abs(b);

        try stdout.writeAll(source[0..byte_pos]);
    } else {
        const line_count = std.mem.count(u8, source, delim);
        const line_pos = if (lines < 0) line_count - @abs(lines) else @abs(lines);

        try stdout.writeAll(source[0..(indexOfCount(u8, source, line_pos, delim) orelse source.len)]);
    }
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

    var bytes: ?isize = null;
    var lines: isize = 10;
    var delim: []const u8 = "\n";

    var files = std.ArrayList(std.fs.File).init(gpa);
    defer {
        for (files.items) |file| file.close();
        files.deinit();
    }

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "-c") or std.mem.startsWith(u8, arg, "--bytes=")) {
            bytes = try std.fmt.parseInt(
                isize,
                blk: {
                    if (std.mem.startsWith(u8, arg, "--bytes=")) break :blk arg[8..];
                    if (std.mem.startsWith(u8, arg, "-c") and arg.len > 2) break :blk arg[2..];
                    break :blk args.next() orelse return error.MissingArgument;
                },
                10,
            );
        } else if (std.mem.startsWith(u8, arg, "-n") or std.mem.eql(u8, arg, "--lines")) {
            lines = try std.fmt.parseInt(
                isize,
                blk: {
                    if (std.mem.startsWith(u8, arg, "--lines=")) break :blk arg[8..];
                    if (std.mem.startsWith(u8, arg, "-n") and arg.len > 2) break :blk arg[2..];
                    break :blk args.next() orelse return error.MissingArgument;
                },
                10,
            );
        } else if (std.mem.startsWith(u8, arg, "--zero-terminated")) {
            delim = &.{0};
        } else if (std.mem.startsWith(u8, arg, "-")) {
            const stderr = std.io.getStdErr().writer().any();
            try stderr.print("head: unknown argument {s}\n", .{arg});
            std.process.exit(1);
        } else {
            try files.append(if (std.fs.path.isAbsolute(arg)) try std.fs.openFileAbsolute(arg, .{}) else try std.fs.cwd().openFile(arg, .{}));
        }
    }

    if (files.items.len == 0) {
        try head(bytes, lines, delim, std.io.getStdIn(), gpa);
    } else {
        for (files.items) |file| try head(bytes, lines, delim, file, gpa);
    }
}
