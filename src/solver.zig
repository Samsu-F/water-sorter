const std = @import("std");
const Game = @import("game.zig");
const DebugUtils = @import("debug_utils.zig");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const GameView = Game.GameView;
const HashSet = std.HashMap(GameView, void, Context, std.hash_map.default_max_load_percentage);

const Context = struct {
    allocator: Allocator,

    // less-than function for sorting
    fn compareTubes(_: void, a: Game.Tube, b: Game.Tube) bool {
        // Lexicographic comparison
        for (a.segments, b.segments) |seg_a, seg_b| {
            if (seg_a < seg_b) return true;
            if (seg_a > seg_b) return false;
        } else return false; // if all segments are equal
    }

    pub fn hash(c: Context, gameview: GameView) u64 {
        var gameview_sorted_copy = gameview.dupe(c.allocator) catch unreachable;
        defer gameview_sorted_copy.deinit(c.allocator);

        std.mem.sort(Game.Tube, gameview_sorted_copy.tubes, {}, compareTubes);
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, gameview_sorted_copy, .Deep);
        return hasher.final();
    }

    pub fn eql(c: Context, gv1: GameView, gv2: GameView) bool {
        var gv1_sorted_copy = gv1.dupe(c.allocator) catch unreachable;
        defer gv1_sorted_copy.deinit(c.allocator);
        var gv2_sorted_copy = gv2.dupe(c.allocator) catch unreachable;
        defer gv2_sorted_copy.deinit(c.allocator);

        std.mem.sort(Game.Tube, gv1_sorted_copy.tubes, {}, compareTubes);
        std.mem.sort(Game.Tube, gv2_sorted_copy.tubes, {}, compareTubes);
        for (gv1_sorted_copy.tubes, gv2_sorted_copy.tubes) |t1, t2| {
            if (!std.meta.eql(t1, t2)) {
                return false;
            }
        } else return true;
    }
};

pub const Move = struct { source: usize, target: usize };

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

fn searchTreeSolve(alloc: Allocator, gameview: GameView, comptime container_policy: ExtractionPolicy) !ArrayList(Move) {
    var states_to_visit = LinearContainer(struct { GameView, ArrayList(Move) }, container_policy).init(alloc);
    defer {
        while (states_to_visit.pop()) |elem| {
            var move_list = elem.@"1";
            move_list.deinit(alloc);
        }
    }
    var known_game_states = HashSet.initContext(alloc, .{ .allocator = alloc });
    defer {
        var iterator = known_game_states.keyIterator();
        while (iterator.next()) |g| {
            g.deinit(alloc);
        }
        known_game_states.deinit();
    }
    const gameview_copy = try gameview.dupe(alloc);
    try states_to_visit.push(.{ gameview_copy, ArrayList(Move).empty });
    try known_game_states.put(gameview_copy, {});
    while (states_to_visit.pop()) |elem| {
        var g, var move_list = elem;
        DebugUtils.print("{f}\n{any}\nknown_game_states.count() == {}\n\n", .{ g, move_list.items, known_game_states.count() });
        errdefer move_list.deinit(alloc);
        if (g.is_solved()) {
            DebugUtils.print("found solution with {} moves after {} push operations\n", .{ move_list.items.len, known_game_states.count() });
            return move_list;
        }
        defer move_list.deinit(alloc);
        for (g.tubes, 0..) |*tube_source, i_source| {
            for (g.tubes, 0..) |*tube_target, i_target| {
                if (move_list.getLastOrNull()) |last_move| {
                    if (i_source == last_move.target) {
                        continue; // never make a move that pours out what was just poured in
                    }
                    if (g.tubes[last_move.source].topSegment() == g.tubes[last_move.target].topSegment()) {
                        // if last move was a partial pour of multiple segments of the same color
                        if (last_move.source != i_source) {
                            continue; // partial pour must be continued, otherwise it did not make sense
                        }
                    }
                }
                if (tube_source.try_transfer(tube_target, false)) {
                    var g_copy = try g.dupe(alloc);
                    _ = g_copy.tubes[i_source].try_transfer(&g_copy.tubes[i_target], true);
                    if (!known_game_states.contains(g_copy)) {
                        try known_game_states.put(g_copy, {});
                        var move_list_copy = try move_list.clone(alloc);
                        try move_list_copy.append(alloc, .{ .source = i_source, .target = i_target });
                        try states_to_visit.push(.{ g_copy, move_list_copy });
                    } else {
                        g_copy.deinit(alloc);
                    }
                }
            }
        }
    }
    @panic("no solution");
}

pub fn bfsSolve(alloc: Allocator, gameview: GameView) !ArrayList(Move) {
    return searchTreeSolve(alloc, gameview, .fifo); // use a queue
}

pub fn dfsSolve(alloc: Allocator, gameview: GameView) !ArrayList(Move) {
    return searchTreeSolve(alloc, gameview, .lifo); // use a stack
}
