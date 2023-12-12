const builtin = @import("builtin");
const std = @import("std");
const common = @import("common.zig");
const alloc = common.allocator;

pub usingnamespace switch (builtin.os.tag) {
    .uefi => struct {
        const StoWriter = std.io.Writer(*std.os.uefi.protocol.SimpleTextOutput, std.os.uefi.Status.EfiError || std.mem.Allocator.Error || error{InvalidUtf8}, stoWrite);

        fn stoWrite(sto: *std.os.uefi.protocol.SimpleTextOutput, buf: []const u8) !usize {
            const buf16 = try std.unicode.utf8ToUtf16LeWithNull(alloc, buf);
            defer alloc.free(buf16);
            try sto.outputString(buf16).err();
            return buf.len;
        }

        pub inline fn getStdErr() StoWriter {
            return StoWriter{ .context = std.os.uefi.system_table.std_err.? };
        }

        pub inline fn getStdOut() StoWriter {
            return StoWriter{ .context = std.os.uefi.system_table.con_out.? };
        }
    },
    else => struct {
        pub inline fn getStdErr() std.fs.File.Writer {
            return std.io.getStdErr().writer();
        }

        pub inline fn getStdOut() std.fs.File.Writer {
            return std.io.getStdOut().writer();
        }
    },
};
