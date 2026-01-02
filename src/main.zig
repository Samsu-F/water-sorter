const std = @import("std");
const parser = @import("parser.zig");
const solver = @import("solver.zig");
const Game = @import("game.zig");
const DebugUtils = @import("debug_utils.zig");
const Image = @import("zigimg").Image;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn main() !void {
    var debug_alloc = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_alloc.deinit();
    const alloc = debug_alloc.allocator();

    var game = try parser.parseGame(alloc, try getImg(alloc));
    defer game.deinit();
    var moves = try solver.bfsSolve(alloc, game.view());
    defer moves.deinit(alloc);
    DebugUtils.print("Main: solution = {any}\n", .{moves.items});
    try executeSolution(game, moves);
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

fn executeSolution(game: Game, move_list: ArrayList(solver.Move)) !void {
    for (move_list.items) |move| {
        const x1: usize = game.positions[move.source].x;
        const y1: usize = game.positions[move.source].y;
        const x2: usize = game.positions[move.target].x;
        const y2: usize = game.positions[move.target].y;
        DebugUtils.print("tapping at {:4}/{:4} ", .{ x1, y1 });
        var tap1 = try adbTap(game.allocator, x1, y1);
        std.Thread.sleep(200 * std.time.ns_per_ms);
        DebugUtils.print("and at {:4}/{:4}\n", .{ x2, y2 });
        var tap2 = try adbTap(game.allocator, x2, y2);
        _ = try tap1.wait();
        _ = try tap2.wait();
    }
}

fn adbTap(alloc: Allocator, x: usize, y: usize) !std.process.Child {
    var x_string: [10]u8 = undefined;
    var y_string: [10]u8 = undefined;
    const x_length = std.fmt.printInt(&x_string, x, 10, .lower, .{});
    const y_length = std.fmt.printInt(&y_string, y, 10, .lower, .{});
    var exe = std.process.Child.init(&.{ "adb", "shell", "input", "touchscreen", "tap", x_string[0..x_length], y_string[0..y_length] }, alloc);
    try exe.spawn();
    return exe;
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
