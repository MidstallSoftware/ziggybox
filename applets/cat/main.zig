const builtin = @import("builtin");
const std = @import("std");
const native_os = builtin.os.tag;

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

    var i: usize = 0;

    const raw_stdout = std.io.getStdOut().writer().any();
    var buffered_stdout = std.io.bufferedWriter(raw_stdout);
    defer buffered_stdout.flush() catch |err| std.debug.panic("Failed to flush stdout: {}", .{err});
    const stdout = buffered_stdout.writer().any();

    while (args.next()) |p| : (i += 1) {
        var file = if (std.fs.path.isAbsolute(p)) try std.fs.openFileAbsolute(p, .{}) else try std.fs.cwd().openFile(p, .{});
        defer file.close();

        const reader = file.reader();

        while (reader.readByte() catch null) |b| try stdout.writeByte(b);
    }

    if (i == 0) {
        const stderr = std.io.getStdErr().writer().any();
        try stderr.writeAll("cat: path is required\n");
        std.process.exit(1);
    }
}
