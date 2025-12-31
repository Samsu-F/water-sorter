const std = @import("std");
const Game = @import("game.zig");
const ArrayList = std.ArrayList;
const HashSet = std.AutoHashMap(Game, void);

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();

        const QueueNode: type = struct { data: T, node: std.DoublyLinkedList.Node };

        allocator: std.mem.Allocator,
        list: std.DoublyLinkedList,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .list = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            // Free all remaining nodes
            while (self.dequeue() != null) {}
        }

        pub fn isEmpty(self: *Self) bool {
            return self.list.len == 0;
        }

        pub fn enqueue(self: *Self, value: T) !void {
            const qnode = try self.allocator.create(QueueNode);
            qnode.* = .{ .data = value, .node = .{} };
            self.list.append(&qnode.node);
        }

        pub fn dequeue(self: *Self) ?T {
            const node = self.list.popFirst() orelse return null;
            const qnode: *QueueNode = @fieldParentPtr("node", node);
            defer self.allocator.destroy(qnode);
            return qnode.*.data;
        }

        pub fn peek(self: *Self) ?*const T {
            const node = self.list.first orelse return null;
            const qnode: *QueueNode = @fieldParentPtr("node", node);
            return &qnode.*.data;
        }
    };
}

pub const Move = struct { source: usize, target: usize };

// pub fn solveGame(game: Game) void {
//     // var graph = std.AutoHashMap(*Game, std.AutoHashMap(struct { usize, usize }, *Game)).init(game.allocator);

//     for (game.tubes, 0..) |*t1, i| {
//         for (game.tubes, 0..) |*t2, j| {
//             // if (i != j) {
//             if (t1.try_transfer(t2, false)) {
//                 std.log.debug("{} {}\n", .{ i, j });
//             }
//             // }
//         }
//     }
// }

pub fn bfsSolve(game: Game) !ArrayList(Move) {
    var debug_enqueue_count: usize = 0;
    var queue = Queue(struct { Game, ArrayList(Move) }).init(game.allocator);
    defer {
        while (queue.dequeue()) |elem| {
            var g, var move_list = elem;
            g.deinit();
            move_list.deinit(game.allocator);
        }
    }
    var known_game_states = HashSet.init(game.allocator);
    defer known_game_states.deinit();
    try queue.enqueue(.{ try game.dupe(), ArrayList(Move).empty });
    try known_game_states.put(game, {});
    debug_enqueue_count += 1;
    while (queue.dequeue()) |elem| {
        var g, var move_list = elem;
        std.log.debug("{f}\n{any}\ndebug_enqueue_count = {}\n\n", .{ g, move_list.items, debug_enqueue_count });
        defer g.deinit();
        errdefer move_list.deinit(game.allocator);
        if (g.is_solved()) {
            std.log.debug("found solution after {} enqueue operations\n", .{debug_enqueue_count});
            return move_list;
        }
        defer move_list.deinit(game.allocator);
        for (g.tubes, 0..) |*tube_source, i_source| {
            var empty_target_tried: bool = false;
            for (g.tubes, 0..) |*tube_target, i_target| {
                if (tube_target.colorCount() == 0) {
                    if (tube_source.colorCount() <= 1) {
                        continue; // pouring the whole content of a tube to an empty tube never makes sense
                    }
                    if (empty_target_tried) {
                        continue; // enqueue at most one move with empty target per source
                    }
                    empty_target_tried = true;
                }
                if (move_list.getLastOrNull()) |last_move| {
                    if (i_source == last_move.target) {
                        continue; // never make a move that pours out what was just poured in
                    }
                }
                if (tube_source.colorCount() == 1 and tube_target.colorCount() == 1 and i_source > i_target) {
                    continue; // only pour from lower to higher if the results are equivalent
                }
                if (tube_source.try_transfer(tube_target, false)) {
                    var g_copy = try g.dupe();
                    _ = g_copy.tubes[i_source].try_transfer(&g_copy.tubes[i_target], true);
                    if (!known_game_states.contains(g_copy)) {
                        known_game_states.put(g_copy, {});
                        var move_list_copy = try move_list.clone(g.allocator);
                        try move_list_copy.append(g.allocator, .{ .source = i_source, .target = i_target });
                        try queue.enqueue(.{ g_copy, move_list_copy });
                        debug_enqueue_count += 1;
                    } else {
                        g_copy.deinit();
                    }
                }
            }
        }
    }
    @panic("no solution");
}
