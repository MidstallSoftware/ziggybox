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

    if (args.next()) |comp| {
        const basename = std.fs.path.basename(comp);
        const stdout = std.io.getStdOut().writer().any();
        try stdout.writeAll(if (basename.len == 0) "/" else basename);
        try stdout.writeByte('\n');
    } else {
        const stderr = std.io.getStdErr().writer().any();
        try stderr.writeAll("basename: path is required\n");
        std.process.exit(1);
    }
}
