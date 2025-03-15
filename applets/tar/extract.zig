const std = @import("std");
const Operation = @import("main.zig").Operation;

const Source = union(enum) {
    stdin: void,
    file: std.fs.File,

    pub fn readAllAlloc(self: *Source, gpa: std.mem.Allocator) ![]const u8 {
        return switch (self.*) {
            .stdin => std.io.getStdIn().readToEndAlloc(gpa, std.math.maxInt(usize)),
            .file => |file| file.readToEndAlloc(gpa, std.math.maxInt(usize)),
        };
    }

    pub fn reader(self: *Source) std.io.AnyReader {
        return switch (self.*) {
            .stdin => std.io.getStdIn().reader().any(),
            .file => |file| file.reader().any(),
        };
    }

    pub fn close(self: *Source) void {
        return switch (self.*) {
            .stdin => {},
            .file => |file| file.close(),
        };
    }
};

pub fn extract(args: *std.process.ArgIterator, gpa: std.mem.Allocator, flags: []const Operation) !void {
    var source, const is_verbose = blk: {
        var set_source: ?Source = null;
        var set_verbose = false;
        for (flags) |flag| {
            switch (flag) {
                .f => {
                    const arg = args.next() orelse return error.MissingArgument;
                    set_source = .{
                        .file = if (std.fs.path.isAbsolute(arg)) try std.fs.openFileAbsolute(arg, .{
                            .mode = .read_only,
                        }) else try std.fs.cwd().openFile(arg, .{
                            .mode = .read_only,
                        }),
                    };
                },
                .v => set_verbose = true,
                else => return error.UnknownFlag,
            }
        }
        break :blk .{ set_source orelse .stdin, set_verbose };
    };
    defer source.close();

    const source_buffer = try source.readAllAlloc(gpa);
    defer gpa.free(source_buffer);

    var fixed_buffer_source = std.io.fixedBufferStream(source_buffer);

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    try std.compress.gzip.decompress(fixed_buffer_source.reader(), buffer.writer());

    var fixed_buffer_tmp = std.io.fixedBufferStream(buffer.items);

    // TODO: support destination path
    try std.tar.pipeToFileSystem(std.fs.cwd(), fixed_buffer_tmp.reader(), .{});

    _ = is_verbose;
}
