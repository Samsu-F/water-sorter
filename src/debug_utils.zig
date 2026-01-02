const std = @import("std");

const do_debug_printing: bool = true;

pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (do_debug_printing) {
        std.debug.print(fmt, args);
    }
}
