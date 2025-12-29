const std = @import("std");
const water_sorter = @import("water_sorter");
const fs = std.fs;
const heap = std.heap;
const math = std.math;
const process = std.process;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const zigimg = @import("zigimg");
const Image = water_sorter.Image;

fn getImg(alloc: Allocator) !Image {
    var exe = process.Child.init(&.{ "adb", "exec-out", "screencap", "-p" }, alloc);
    var out = ArrayList(u8).empty;
    defer out.deinit(alloc);
    var err = ArrayList(u8).empty;
    defer err.deinit(alloc);

    exe.stdout_behavior = .Pipe;
    exe.stderr_behavior = .Pipe;
    try exe.spawn();
    try exe.collectOutput(alloc, &out, &err, math.maxInt(usize));
    _ = try exe.wait();

    const image = try Image.fromMemory(alloc, out.items);

    return image;
}

pub fn main() !void {
    var debug_alloc = heap.DebugAllocator(.{}).init;
    const alloc = debug_alloc.allocator();

    const img = try getImg(alloc);
    for (img.pixels.rgb24) |pixel| {
        std.debug.print("{} {} {}\n", .{ pixel.r, pixel.g, pixel.b });
    }
}

// test "simple test" {
//     const gpa = std.testing.allocator;
//     var list: std.ArrayList(i32) = .empty;
//     defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
//     try list.append(gpa, 42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
