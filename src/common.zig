const builtin = @import("builtin");
const std = @import("std");

pub const allocator = if (builtin.os.tag == .uefi) std.os.uefi.pool_allocator else std.heap.page_allocator;

pub const ArgIterator = if (builtin.os.tag == .uefi) struct {
    pub fn initWithAllocator(alloc: std.mem.Allocator) !@This() {
        _ = alloc;
        return .{};
    }

    pub fn next(_: *@This()) ?[]const u8 {
        return null;
    }

    pub fn deinit(_: *@This()) void {}
} else std.process.ArgIterator;
