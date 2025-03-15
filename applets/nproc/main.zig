const builtin = @import("builtin");
const std = @import("std");

fn countUnknown() !usize {
    return 1;
}

const count = blk: {
    const impls = struct {
        pub fn linux() !usize {
            var dir = try std.fs.openDirAbsolute("/sys/devices/system/cpu", .{ .iterate = true });
            defer dir.close();

            var i: usize = 0;

            var iter = dir.iterate();
            while (try iter.next()) |entry| {
                if (std.mem.startsWith(u8, entry.name, "cpu")) {
                    if (std.fmt.parseInt(usize, entry.name[3..], 10) catch null) |_| {
                        i += 1;
                    }
                }
            }
            return i;
        }
    };

    break :blk if (@hasDecl(impls, @tagName(builtin.os.tag))) @field(impls, @tagName(builtin.os.tag)) else countUnknown;
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer().any();
    try stdout.print("{}\n", .{try count()});
}
