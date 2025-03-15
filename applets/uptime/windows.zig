const std = @import("std");

pub extern fn GetTickCount64() callconv(std.os.windows.WINAPI) c_ulonglong;
