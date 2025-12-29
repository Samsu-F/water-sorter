//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const Game = @import("game.zig");
const zigimg = @import("zigimg");
const Image = zigimg.Image;

pub fn parseGame(img: Image) !Game {
    _ = img;
    unreachable;
}

// test "basic add functionality" {
//     try std.testing.expect(add(3, 7) == 10);
// }
