const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Segment = u24;

pub const Tube = struct {
    pub const N_SEGMENTS = 4;

    segments: [N_SEGMENTS]Segment,
    tap_position: struct { x: usize, y: usize },

    const empty = Tube{ .segments = .{0} ** N_SEGMENTS };

    fn top(self: Tube) ?u2 {
        for (self.segments, 0..) |s, i| {
            if (s != 0) {
                return @intCast(i);
            }
        } else return null;
    }

    fn bottom(self: Tube, top_i: u2) ?u4 {
        const val = self.segments[top_i];
        for (top_i..N_SEGMENTS) |i| {
            if (self.segments[i] != val) {
                return @intCast(i);
            }
        } else return null;
    }

    pub fn try_tranfer(self: *Tube, other: *Tube, comptime execute: bool) bool {
        if (self == other) return false;

        if (self.top()) |i| {
            const b = self.bottom(i) orelse N_SEGMENTS;
            if (i == 0 and b == N_SEGMENTS) return false;

            if (other.top()) |j| {
                const v1 = self.segments[i];
                const v2 = other.segments[j];

                if (j != 0 and v1 == v2) {
                    if (execute) {
                        const usable: u4 = @min(b - i, j);

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
};

allocator: Allocator,
tubes: []Tube,

pub fn init(alloc: Allocator, tubes: []Tube) Self {
    return .{ .allocator = alloc, .tubes = tubes };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.tubes);
}

pub fn dupe(self: Self) !Self {
    return .{ .allocator = self.allocator, .tubes = self.allocator.dupe(Tube, self.tubes) };
}

pub fn format(self: *const Self, w: *std.io.Writer) !void {
    for (self.tubes) |tube| {
        try w.print("{any}\n", .{tube.segments});
    }
}
