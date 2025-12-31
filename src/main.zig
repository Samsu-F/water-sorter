const std = @import("std");
const parser = @import("parser.zig");
const solver = @import("solver.zig");
const Game = @import("game.zig");
const Image = @import("zigimg").Image;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var debug_alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_alloc.deinit();
    const alloc = debug_alloc.allocator();

    var img = try getImg(alloc);
    defer img.deinit(alloc);
    var game = try parser.parseGame(alloc, &img);
    defer game.deinit();
}

fn getImg(alloc: Allocator) !Image {
    var exe = std.process.Child.init(&.{ "adb", "exec-out", "screencap", "-p" }, alloc);
    exe.stdout_behavior = .Pipe;
    try exe.spawn();

    var poller = std.io.poll(alloc, enum { stdout }, .{ .stdout = exe.stdout.? });
    defer poller.deinit();
    const reader = poller.reader(.stdout);
    while (try poller.poll()) {}
    _ = try exe.wait();

    return Image.fromMemory(alloc, reader.buffer[0..reader.end]);
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
