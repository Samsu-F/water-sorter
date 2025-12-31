const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Segment = u24;
pub const Tube = struct {
    segments: [4]Segment,
    tap_position: struct { x: usize, y: usize },
};

allocator: Allocator,
tubes: []Tube,

pub fn init(alloc: Allocator, tubes: []Tube) Self {
    return .{ .allocator = alloc, .tubes = tubes };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.tubes);
}
