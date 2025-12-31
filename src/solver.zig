const std = @import("std");
const Game = @import("game.zig");
const ArrayList = std.ArrayList;

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

const Move = struct { source: usize, target: usize };

// pub fn solveGame(game: Game) void {
//     // var graph = std.AutoHashMap(*Game, std.AutoHashMap(struct { usize, usize }, *Game)).init(game.allocator);

//     for (game.tubes, 0..) |*t1, i| {
//         for (game.tubes, 0..) |*t2, j| {
//             // if (i != j) {
//             if (t1.try_transfer(t2, false)) {
//                 std.debug.print("{} {}\n", .{ i, j });
//             }
//             // }
//         }
//     }
// }

pub fn bfsSolve(game: Game) !ArrayList(Move) {
    var queue = Queue(struct { Game, ArrayList(Move) }).init(game.allocator);
    defer {
        while (queue.dequeue()) |elem| {
            var g, var move_list = elem;
            g.deinit();
            move_list.deinit(game.allocator);
        }
    }
    try queue.enqueue(.{ try game.dupe(), ArrayList(Move).empty });
    while (queue.dequeue()) |elem| {
        var g, var move_list = elem;
        // std.debug.print("{f}\n{any}\n\n", .{g, move_list.items});
        defer g.deinit();
        errdefer move_list.deinit(game.allocator);
        if (g.is_solved()) {
            return move_list;
        }
        defer move_list.deinit(game.allocator);
        for (g.tubes, 0..) |*tube_source, i_source| {
            for (g.tubes, 0..) |*tube_target, i_target| {
                if (tube_source.try_transfer(tube_target, false)) {
                    var g_copy = try g.dupe();
                    _ = g_copy.tubes[i_source].try_transfer(&g_copy.tubes[i_target], true);
                    var move_list_copy = try move_list.clone(g.allocator);
                    try move_list_copy.append(g.allocator, .{ .source = i_source, .target = i_target });
                    try queue.enqueue(.{ g_copy, move_list_copy });
                }
            }
        }
    }
    @panic("no solution");
}
