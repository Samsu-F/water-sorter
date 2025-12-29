const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const Segment = u8;
const Tube = struct { segments: [4]Segment };

allocator: Allocator,
tubes: []Tube,

pub fn init(alloc: Allocator, tubes: []Tube) Self {
    return .{ .allocator = alloc, .tubes = tubes };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.tubes);
}
