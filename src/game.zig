const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Segment = u8;

pub const Point = struct { x: usize, y: usize };

pub const Tube = struct {
    pub const N_SEGMENTS = 4;
    const top_type = std.math.IntFittingRange(0, N_SEGMENTS);
    const bottom_type = std.math.IntFittingRange(0, N_SEGMENTS + 1);

    segments: [N_SEGMENTS]Segment,

    fn top(self: Tube) ?top_type {
        for (self.segments, 0..) |s, i| {
            if (s != 0) {
                return @intCast(i);
            }
        } else return null;
    }

    fn bottom(self: Tube, top_i: top_type) ?bottom_type {
        const val = self.segments[top_i];
        for (top_i..N_SEGMENTS) |i| {
            if (self.segments[i] != val) {
                return @intCast(i);
            }
        } else return null;
    }

    pub fn topSegment(self: Tube) ?Segment {
        const i_top = self.top() orelse return null;
        return self.segments[i_top];
    }

    pub fn try_transfer(self: *Tube, other: *Tube, comptime execute: bool) bool {
        if (self == other) return false;

        if (self.top()) |i| {
            const b = self.bottom(i) orelse N_SEGMENTS;
            if (i == 0 and b == N_SEGMENTS) return false;

            if (other.top()) |j| {
                const v1 = self.segments[i];
                const v2 = other.segments[j];

                if (j != 0 and v1 == v2) {
                    if (execute) {
                        const usable: bottom_type = @min(b - i, j);

                        @memmove(other.segments[j - usable .. j], self.segments[i .. i + usable]);
                        @memset(self.segments[i .. i + usable], 0);
                    }
                    return true;
                }
            } else {
                if (execute) {
                    @memmove(other.segments[N_SEGMENTS - b + i ..], self.segments[i..b]);
                    @memset(self.segments[i..b], 0);
                }
                return true;
            }
        }

        return false;
    }

    pub fn colorCount(self: Tube) usize {
        var color_count: usize = 0;
        var current_color: u24 = 0;
        for (self.segments) |segment| {
            if (segment != current_color) {
                color_count += 1;
                current_color = segment;
            }
        }
        return color_count;
    }
};

pub const GameView = struct {
    tubes: []Tube,

    pub fn dupe(self: GameView, alloc: Allocator) !GameView {
        return .{ .tubes = try alloc.dupe(Tube, self.tubes) };
    }

    pub fn deinit(self: *GameView, alloc: Allocator) void {
        alloc.free(self.tubes);
    }

    pub fn format(self: *const GameView, w: *std.io.Writer) !void {
        for (self.tubes) |tube| {
            for (tube.segments) |segment| {
                try w.print("{} ", .{segment});
            }
            try w.writeByte('\n');
        }
    }

    pub fn is_solved(self: GameView) bool {
        for (self.tubes) |tube| {
            for (tube.segments[1..]) |s| {
                if (s != tube.segments[0]) return false;
            }
        } else return true;
    }
};

allocator: Allocator,
tubes: []Tube,
positions: []Point,

pub fn init(alloc: Allocator, tubes: []Tube, positions: []Point) Self {
    return .{ .allocator = alloc, .tubes = tubes, .positions = positions };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.tubes);
    self.allocator.free(self.positions);
}

pub fn view(self: Self) GameView {
    return .{ .tubes = self.tubes };
}
