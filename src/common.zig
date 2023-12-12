const builtin = @import("builtin");
const std = @import("std");

pub const allocator = if (builtin.os.tag == .uefi) std.os.uefi.pool_allocator else std.heap.page_allocator;
