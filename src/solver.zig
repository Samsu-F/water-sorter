const std = @import("std");
const Game = @import("game.zig");

pub fn solveGame(game: Game) void {
    // var graph = std.AutoHashMap(*Game, std.AutoHashMap(struct { usize, usize }, *Game)).init(game.allocator);

    for (game.tubes, 0..) |*t1, i| {
        for (game.tubes, 0..) |*t2, j| {
            // if (i != j) {
            if (t1.try_transfer(t2, false)) {
                std.debug.print("{} {}\n", .{ i, j });
            }
            // }
        }
    }
}
