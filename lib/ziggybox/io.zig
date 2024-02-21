const builtin = @import("builtin");
const std = @import("std");
const common = @import("common.zig");
const alloc = common.allocator;

pub usingnamespace switch (builtin.os.tag) {
    .uefi => struct {
        const StoWriter = std.io.Writer(*std.os.uefi.protocol.SimpleTextOutput, std.os.uefi.Status.EfiError || std.mem.Allocator.Error || error{InvalidUtf8}, stoWrite);
        const StiReader = std.io.Reader(*std.os.uefi.protocol.SimpleTextInput, std.os.uefi.Status.EfiError || std.mem.Allocator.Error, stiRead);

        fn stoWrite(sto: *std.os.uefi.protocol.SimpleTextOutput, buf: []const u8) !usize {
            const buf16 = try std.unicode.utf8ToUtf16LeWithNull(alloc, buf);
            defer alloc.free(buf16);
            try sto.outputString(buf16).err();
            if (buf.len > 0) {
                if (buf[buf.len - 1] == '\n') try sto.outputString(&[1:0]u16{0x000D}).err();
            }
            return buf.len;
        }

        fn stiRead(sti: *std.os.uefi.protocol.SimpleTextInput, buf: []const u8) !usize {
            _ = sti;
            _ = buf;
            return 0;
        }

        pub inline fn getStdErr() StoWriter {
            return StoWriter{ .context = std.os.uefi.system_table.std_err.? };
        }

        pub inline fn getStdOut() StoWriter {
            return StoWriter{ .context = std.os.uefi.system_table.con_out.? };
        }

        pub inline fn getStdIn() StiReader {
            return StiReader{ .context = std.os.uefi.system_table.con_in.? };
        }
    },
    else => struct {
        pub inline fn getStdErr() std.fs.File.Writer {
            return std.io.getStdErr().writer();
        }

        pub inline fn getStdOut() std.fs.File.Writer {
            return std.io.getStdOut().writer();
        }

        pub inline fn getStdIn() std.fs.File.Reader {
            return std.io.getStdOut().reader();
        }
    },
};
