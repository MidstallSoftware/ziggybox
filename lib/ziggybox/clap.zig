// Code from https://github.com/Hejsil/zig-clap/blob/master/clap.zig licensed under MIT
const clap = @import("clap");
const std = @import("std");
const common = @import("common.zig");

fn findPositional(comptime Id: type, params: []const clap.Param(Id)) ?clap.Param(Id) {
    for (params) |param| {
        const longest = param.names.longest();
        if (longest.kind == .positional)
            return param;
    }

    return null;
}

fn ParamType(
    comptime Id: type,
    comptime param: clap.Param(Id),
    comptime value_parsers: anytype,
) type {
    const parser = switch (param.takes_value) {
        .none => clap.parsers.string,
        .one, .many => @field(value_parsers, param.id.value()),
    };
    return clap.parsers.Result(@TypeOf(parser));
}

fn FindPositionalType(
    comptime Id: type,
    comptime params: []const clap.Param(Id),
    comptime value_parsers: anytype,
) type {
    const pos = findPositional(Id, params) orelse return []const u8;
    return ParamType(Id, pos, value_parsers);
}

fn parseArg(
    comptime Id: type,
    comptime param: clap.Param(Id),
    comptime value_parsers: anytype,
    allocator: std.mem.Allocator,
    arguments: anytype,
    positionals: anytype,
    arg: clap.streaming.Arg(Id),
) !void {
    const parser = comptime switch (param.takes_value) {
        .none => undefined,
        .one, .many => @field(value_parsers, param.id.value()),
    };

    const longest = comptime param.names.longest();
    const name = longest.name[0..longest.name.len].*;
    switch (longest.kind) {
        .short, .long => switch (param.takes_value) {
            .none => @field(arguments, &name) +|= 1,
            .one => @field(arguments, &name) = try parser(arg.value.?),
            .many => {
                const value = try parser(arg.value.?);
                try @field(arguments, &name).append(allocator, value);
            },
        },
        .positional => try positionals.append(try parser(arg.value.?)),
    }
}

fn deinitArgs(
    comptime Id: type,
    comptime params: []const clap.Param(Id),
    allocator: std.mem.Allocator,
    arguments: anytype,
) void {
    inline for (params) |param| {
        const longest = comptime param.names.longest();
        if (longest.kind == .positional)
            continue;
        if (param.takes_value != .many)
            continue;

        const field = @field(arguments, longest.name);

        // If the multi value field is a struct, we know it is a list and should be deinited.
        // Otherwise, it is a slice that should be freed.
        switch (@typeInfo(@TypeOf(field))) {
            .Struct => @field(arguments, longest.name).deinit(allocator),
            else => allocator.free(@field(arguments, longest.name)),
        }
    }
}

const MultiArgKind = enum { slice, list };

fn Arguments(
    comptime Id: type,
    comptime params: []const clap.Param(Id),
    comptime value_parsers: anytype,
    comptime multi_arg_kind: MultiArgKind,
) type {
    var fields: [params.len]std.builtin.Type.StructField = undefined;

    var i: usize = 0;
    for (params) |param| {
        const longest = param.names.longest();
        if (longest.kind == .positional)
            continue;

        const T = ParamType(Id, param, value_parsers);
        const default_value = switch (param.takes_value) {
            .none => @as(u8, 0),
            .one => @as(?T, null),
            .many => switch (multi_arg_kind) {
                .slice => @as([]const T, &[_]T{}),
                .list => std.ArrayListUnmanaged(T){},
            },
        };

        const name = longest.name[0..longest.name.len] ++ "";
        fields[i] = .{
            .name = name,
            .type = @TypeOf(default_value),
            .default_value = @ptrCast(&default_value),
            .is_comptime = false,
            .alignment = @alignOf(@TypeOf(default_value)),
        };
        i += 1;
    }

    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = fields[0..i],
        .decls = &.{},
        .is_tuple = false,
    } });
}

pub const ParseOptions = struct {
    allocator: std.mem.Allocator = common.allocator,
    diagnostic: ?*clap.Diagnostic = null,
    limit: bool = false,
};

pub fn parse(comptime Id: type, comptime params: []const clap.Param(Id), comptime value_parsers: anytype, opt: ParseOptions) !clap.ResultEx(Id, params, value_parsers) {
    var iter = try std.process.ArgIterator.initWithAllocator(opt.allocator);
    defer iter.deinit();

    _ = iter.next();
    return parseEx(Id, params, value_parsers, &iter, opt);
}

pub fn parseEx(
    comptime Id: type,
    comptime params: []const clap.Param(Id),
    comptime value_parsers: anytype,
    iter: anytype,
    opt: ParseOptions,
) !clap.ResultEx(Id, params, value_parsers) {
    const Positional = FindPositionalType(Id, params, value_parsers);

    var positionals = std.ArrayList(Positional).init(opt.allocator);
    var arguments = Arguments(Id, params, value_parsers, .list){};
    errdefer deinitArgs(Id, params, opt.allocator, &arguments);

    var stream = clap.streaming.Clap(Id, std.meta.Child(@TypeOf(iter))){
        .params = params,
        .iter = iter,
        .diagnostic = opt.diagnostic,
    };

    var i: usize = 1;
    while (try stream.next()) |arg| {
        var res: anyerror!void = {};
        var willBreak = false;
        inline for (params, 0..) |*param, x| {
            if (param == arg.param) {
                res = parseArg(
                    Id,
                    param.*,
                    value_parsers,
                    opt.allocator,
                    &arguments,
                    &positionals,
                    arg,
                );

                if (opt.limit) {
                    if (i == x and x == (params.len - 1)) willBreak = true;
                }
            }
        }

        try res;
        i += 1;

        if (willBreak) break;
    }

    var result_args = @typeInfo(clap.ResultEx(Id, params, value_parsers)).Struct.fields[0].type{};
    inline for (std.meta.fields(@TypeOf(arguments))) |field| {
        if (@typeInfo(field.type) == .Struct and
            @hasDecl(field.type, "toOwnedSlice"))
        {
            const slice = try @field(arguments, field.name).toOwnedSlice(opt.allocator);
            @field(result_args, field.name) = slice;
        } else {
            @field(result_args, field.name) = @field(arguments, field.name);
        }
    }

    return clap.ResultEx(Id, params, value_parsers){
        .args = result_args,
        .positionals = try positionals.toOwnedSlice(),
        .allocator = opt.allocator,
    };
}
