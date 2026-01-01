const std = @import("std");
const zigimg = @import("zigimg");
const Game = @import("game.zig");
const Tube = Game.Tube;
const Image = zigimg.Image;
const Bgr24 = zigimg.color.Bgr24;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Color = struct {
    const Self = @This();

    val: Bgr24,

    const Wall1 = Self{ .val = .{ .r = 0xd6, .g = 0xc6, .b = 0xde } };
    const Wall2 = Self{ .val = .{ .r = 0x4a, .g = 0x41, .b = 0x5a } };
    const Bg1 = Self{ .val = .{ .r = 0x21, .g = 0x18, .b = 0x29 } };
    const Bg2 = Self{ .val = .{ .r = 0x29, .g = 0x20, .b = 0x3a } };
    const Black = Self{ .val = .{ .r = 0, .g = 0, .b = 0 } };

    fn fromImage(img: Image, x: usize, y: usize) Self {
        std.debug.assert(img.pixelFormat() == .bgr24);
        return .{ .val = img.pixels.bgr24[x + y * img.width] };
    }

    fn toU24(self: Self) u24 {
        return @bitCast(self.val);
    }

    fn isSimilar(self: Self, other: Self) bool {
        const max_accepted_diff = 15;
        const dr = @abs(@as(i8, @bitCast(self.val.r -% other.val.r)));
        const dg = @abs(@as(i8, @bitCast(self.val.g -% other.val.g)));
        const db = @abs(@as(i8, @bitCast(self.val.b -% other.val.b)));
        return @max(dr, dg, db) < max_accepted_diff;
    }

    fn isWallColor(self: Self) bool {
        return self.isSimilar(Wall1) or self.isSimilar(Wall2);
    }

    fn isBgColor(self: Self) bool {
        return self.isSimilar(Bg1) or self.isSimilar(Bg2);
    }
};

const ColorCache = struct {
    const Self = @This();

    alloc: Allocator,
    colors: ArrayList(Color),

    fn init(alloc: Allocator) Self {
        return .{ .alloc = alloc, .colors = .empty };
    }

    fn deinit(self: *Self) void {
        self.colors.deinit(self.alloc);
    }

    fn getSimilar(self: *Self, new_color: Color) !Color {
        for (self.colors.items) |col| {
            if (col.isSimilar(new_color)) {
                return col;
            }
        } else {
            try self.colors.append(self.alloc, new_color);
            return new_color;
        }
    }
};

pub fn parseGame(alloc: Allocator, image: Image) !Game {
    var img = image;
    defer img.deinit(alloc);
    try img.convert(alloc, .bgr24);
    std.log.debug("height x width: {} x {}\n", .{ img.height, img.width });

    var tubes = ArrayList(Tube).empty;
    errdefer tubes.deinit(alloc);
    var cache = ColorCache.init(alloc);
    defer cache.deinit();

    var y: usize = 730;
    while (y < 1850) : (y += 496) {
        var x: usize = 0;
        while (x < img.width) : (x += 4) {
            const color = Color.fromImage(img, x, y);
            if (color.isWallColor()) {
                const x_center = x + 50;

                // go to top of tube (top edge of top segment)
                var y_top = y;
                while (!Color.fromImage(img, x_center, y_top).isWallColor()) y_top -= 4;
                y_top += 72;

                var y_bottom = y_top + 300;
                while (!Color.fromImage(img, x_center, y_bottom).isWallColor()) y_bottom += 4;

                std.log.debug("Tube from {}/{} to {}/{}\n", .{ x_center, y_top, x_center, y_bottom });
                const dy = y_bottom - y_top;
                const y_center = y_top + dy / 2;
                var tube = Tube{ .segments = undefined, .tap_position = .{ .x = x_center, .y = y_center } };
                for (&tube.segments, 0..) |*segment, idx| {
                    const segment_y_center = y_top + (2 * idx + 1) * dy / 8;
                    var segment_color = Color.fromImage(img, x_center, segment_y_center);
                    segment_color = if (segment_color.isBgColor()) .Black else try cache.getSimilar(segment_color);

                    segment.* = segment_color.toU24();
                    std.log.debug("{}/{}:\t#{x:06}\n", .{ x_center, segment_y_center, segment_color.toU24() });
                }
                try tubes.append(alloc, tube);

                x += 156;
                y = y_center;
            }
        }
    }

    for (cache.colors.items) |color| {
        var count: usize = 0;
        for (tubes.items) |t| {
            for (t.segments) |s| {
                if (s == color.toU24()) count += 1;
            }
        }
        std.log.debug("color #{x:06} occurs {} times\n", .{ color.toU24(), count });
        if (color.toU24() == Color.Black.toU24()) {
            std.debug.assert(count == 8); // exactly 8 empty segments
        } else {
            std.debug.assert(count == 4); // each color occurs exactly 4 times
        }
    }

    return Game.init(alloc, try tubes.toOwnedSlice(alloc));
}

// test "basic add functionality" {
//     try std.testing.expect(add(3, 7) == 10);
// }
