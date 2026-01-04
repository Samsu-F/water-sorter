const std = @import("std");
const Game = @import("game.zig");
const DebugUtils = @import("debug_utils.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const HashSet = std.HashMap(Game.GameView, void, Context, std.hash_map.default_max_load_percentage);
const Context = struct {
    pub fn hash(_: Context, gameview: Game.GameView) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, gameview, .Deep);
        return hasher.final();
    }

    pub fn eql(_: Context, gv1: Game.GameView, gv2: Game.GameView) bool {
        for (gv1.tubes, gv2.tubes) |t1, t2| {
            if (!std.mem.eql(Game.Segment, &t1.segments, &t2.segments)) {
                return false;
            }
        }
        return true;
    }
};

pub const ExtractionPolicy = enum { fifo, lifo };

pub fn LinearContainer(comptime T: type, comptime extraction_policy: ExtractionPolicy) type {
    return struct {
        const Self = @This();

        const ContainerNode: type = struct { data: T, node: std.DoublyLinkedList.Node };

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
            while (self.pop() != null) {}
        }

        pub fn isEmpty(self: *Self) bool {
            return self.list.len == 0;
        }

        pub fn push(self: *Self, value: T) !void {
            const container_node = try self.allocator.create(ContainerNode);
            container_node.* = .{ .data = value, .node = .{} };
            self.list.append(&container_node.node);
        }

        pub fn pop(self: *Self) ?T {
            const node = switch (extraction_policy) {
                .fifo => self.list.popFirst(),
                .lifo => self.list.pop(),
            } orelse return null;
            const container_node: *ContainerNode = @fieldParentPtr("node", node);
            defer self.allocator.destroy(container_node);
            return container_node.*.data;
        }

        pub fn peek(self: *Self) ?*const T {
            const node = switch (extraction_policy) {
                .fifo => self.list.first,
                .lifo => self.list.last,
            } orelse return null;
            const container_node: *ContainerNode = @fieldParentPtr("node", node);
            return &container_node.*.data;
        }
    };
}

pub const Move = struct { source: usize, target: usize };

pub const MoveList = struct {
    prev: ?*const MoveList,
    move: Move,

    fn toArrayList(self: *const MoveList, alloc: Allocator) !ArrayList(Move) {
        var array_list = ArrayList(Move).empty;
        var current_node: *const MoveList = self;
        while (true) {
            try array_list.append(alloc, current_node.*.move);
            current_node = current_node.*.prev orelse break;
        }

        // reverse order
        var i: usize = 0;
        while (i < array_list.items.len - i - 1) : (i += 1) {
            const tmp = array_list.items[i];
            array_list.items[i] = array_list.items[array_list.items.len - i - 1];
            array_list.items[array_list.items.len - i - 1] = tmp;
        }
        return array_list;
    }
};

// pub fn solveGame(game: Game) void {
//     // var graph = std.AutoHashMap(*Game, std.AutoHashMap(struct { usize, usize }, *Game)).init(game.allocator);

//     for (game.tubes, 0..) |*t1, i| {
//         for (game.tubes, 0..) |*t2, j| {
//             // if (i != j) {
//             if (t1.try_transfer(t2, false)) {
//                 DebugUtils.print("{} {}\n", .{ i, j });
//             }
//             // }
//         }
//     }
// }

fn searchTreeSolve(alloc: Allocator, gameview: Game.GameView, comptime container_policy: ExtractionPolicy) !ArrayList(Move) {
    var states_to_visit = LinearContainer(struct { Game.GameView, ?*const MoveList }, container_policy).init(alloc);
    defer states_to_visit.deinit();
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer {
        _ = arena.reset(.free_all);
        arena.deinit();
    }
    const arena_alloc = arena.allocator();

    var known_game_states = HashSet.init(alloc);
    defer {
        var iterator = known_game_states.keyIterator();
        while (iterator.next()) |g| {
            g.deinit(alloc);
        }
        known_game_states.deinit();
    }
    const gameview_copy = try gameview.dupe(alloc);
    try states_to_visit.push(.{ gameview_copy, null });
    try known_game_states.put(gameview_copy, {});
    while (states_to_visit.pop()) |elem| {
        var g, const move_list = elem;
        DebugUtils.print("known_game_states.count() == {}\n", .{known_game_states.count()});
        if (g.is_solved()) {
            const ml = move_list orelse return ArrayList(Move).empty;
            const result = try ml.toArrayList(alloc);
            DebugUtils.print("found solution with {} moves after {} push operations\n", .{ result.items.len, known_game_states.count() });
            return result;
        }
        for (g.tubes, 0..) |*tube_source, i_source| {
            var empty_target_tried: bool = false;
            for (g.tubes, 0..) |*tube_target, i_target| {
                if (tube_target.colorCount() == 0) {
                    if (tube_source.colorCount() <= 1) {
                        continue; // pouring the whole content of a tube to an empty tube never makes sense
                    }
                    if (empty_target_tried) {
                        continue; // consider at most one move with empty target per source
                    }
                    empty_target_tried = true;
                }
                if (move_list) |ml| {
                    const last_move: Move = ml.*.move;
                    if (i_source == last_move.target) {
                        continue; // never make a move that pours out what was just poured in
                    }
                }
                if (tube_source.colorCount() == 1 and tube_target.colorCount() == 1 and i_source > i_target) {
                    continue; // only pour from lower to higher if the results are equivalent
                }
                if (tube_source.try_transfer(tube_target, false)) {
                    var g_copy = try g.dupe(alloc);
                    _ = g_copy.tubes[i_source].try_transfer(&g_copy.tubes[i_target], true);
                    if (!known_game_states.contains(g_copy)) {
                        try known_game_states.put(g_copy, {});
                        const move_list_new = try arena_alloc.create(MoveList);
                        move_list_new.*.prev = move_list;
                        move_list_new.*.move = .{ .source = i_source, .target = i_target };
                        try states_to_visit.push(.{ g_copy, move_list_new });
                    } else {
                        g_copy.deinit(alloc);
                    }
                }
            }
        }
    }
    @panic("no solution");
}

pub fn bfsSolve(alloc: Allocator, gameview: Game.GameView) !ArrayList(Move) {
    return searchTreeSolve(alloc, gameview, .fifo); // use a queue
}

pub fn dfsSolve(alloc: Allocator, gameview: Game.GameView) !ArrayList(Move) {
    return searchTreeSolve(alloc, gameview, .lifo); // use a stack
}
