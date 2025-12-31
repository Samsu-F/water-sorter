const std = @import("std");
const zigimg = @import("zigimg");
const Game = @import("game.zig");

pub fn parseGame(img: *zigimg.Image) !Game {
    _ = img;
    unreachable;
}

// test "basic add functionality" {
//     try std.testing.expect(add(3, 7) == 10);
// }
