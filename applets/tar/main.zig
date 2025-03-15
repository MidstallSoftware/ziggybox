const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const native_os = builtin.os.tag;

pub const Operation = enum {
    x,
    v,
    f,
};

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

    if (args.next()) |ops| {
        var opflags = std.ArrayList(Operation).init(gpa);
        defer opflags.deinit();

        for (ops) |op| {
            if (std.meta.stringToEnum(Operation, &.{op})) |flag| {
                try opflags.append(flag);
                continue;
            }
            return error.UnknownFlag;
        }

        assert(opflags.items.len > 0);

        const cmd: *const fn (args: *std.process.ArgIterator, gpa: std.mem.Allocator, flags: []const Operation) anyerror!void = switch (opflags.items[0]) {
            .x => @import("extract.zig").extract,
            else => return error.UnknownOp,
        };

        return try cmd(&args, gpa, opflags.items[1..]);
    }
}
