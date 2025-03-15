const builtin = @import("builtin");
const std = @import("std");
const native_os = builtin.os.tag;

const fields = @import("format.zig");

fn format(writer: anytype, fmt: []const u8, timestamp: i64) !void {
    var i: usize = 0;
    while (i < fmt.len) : (i += 1) {
        if (fmt[i] == '%') {
            var handled = false;
            inline for (comptime std.meta.declarations(fields)) |f| {
                if (std.mem.startsWith(u8, fmt[i..], "%" ++ f.name)) {
                    try @field(fields, f.name)(writer, timestamp);
                    handled = true;
                }
            }

            if (std.mem.startsWith(u8, fmt[i..], "%%")) {
                try writer.writeByte('%');
                handled = true;
            }

            if (handled) {
                i += 1;
                continue;
            }
            return error.InvalidField;
        }

        try writer.writeByte(fmt[i]);
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

    const stdout = std.io.getStdOut().writer().any();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    _ = args.skip();

    const timestamp = std.time.timestamp();

    if (args.next()) |comp| {
        if (std.mem.startsWith(u8, comp, "+")) {
            try format(stdout, comp[1..], timestamp);
            try stdout.writeByte('\n');
        }
    } else {
        try format(stdout, "", timestamp);
        try stdout.writeByte('\n');
    }
}
