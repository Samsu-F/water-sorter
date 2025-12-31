const std = @import("std");
const zigimg = @import("zigimg");
const Game = @import("game.zig");
const Image = zigimg.Image;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

fn rgb(img: *Image, x: usize, y: usize) u24 {
    return @bitCast(img.*.pixels.bgr24[x + y * img.*.width]);
}

fn colors_are_similar(c1: u24, c2: u24) bool {
    const max_accepted_diff: i24 = 15;
    const r1: i24 = (@as(i24, @bitCast(c1 & 0xff0000))) >> 16;
    const r2: i24 = (@as(i24, @bitCast(c2 & 0xff0000))) >> 16;
    const g1: i24 = (@as(i24, @bitCast(c1 & 0xff00))) >> 8;
    const g2: i24 = (@as(i24, @bitCast(c2 & 0xff00))) >> 8;
    const b1: i24 = (@as(i24, @bitCast(c1 & 0xff)));
    const b2: i24 = (@as(i24, @bitCast(c2 & 0xff)));
    return @abs(r1 - r2) < max_accepted_diff and @abs(g1 - g2) < max_accepted_diff and @abs(b1 - b2) < max_accepted_diff;
}

fn is_wall_color(color: u24) bool {
    return colors_are_similar(color, 0xd6c6de) or colors_are_similar(color, 0x4a415a);
}

fn is_bg_color(color: u24) bool {
    return colors_are_similar(color, 0x211829) or colors_are_similar(color, 0x29203a);
}

pub fn parseGame(alloc: Allocator, img: *Image) !Game {
    try img.convert(alloc, .bgr24);
    defer img.deinit(alloc);
    std.debug.print("height x width: {} x {}\n", .{ img.*.height, img.*.width });

    var tubes = ArrayList(Game.Tube).empty;

    var y: usize = 730;
    while (y < img.*.height and y < 1850) : (y += 496) {
        var x: usize = 0;
        while (x < img.*.width) : (x += 4) {
            // std.debug.print("checking color at {}/{}\n", .{ x, y });
            const color: u24 = rgb(img, x, y);
            if (is_wall_color(color)) {
                const x_continue_search: usize = x + 156;
                x += 50;
                while (!is_wall_color(rgb(img, x, y - 4))) {
                    y -= 4; // go to top of tube (top edge of top segment)
                }
                const top_edge: usize = y + 68;
                y += 300;
                while (!is_wall_color(rgb(img, x, y + 1))) {
                    y += 1;
                }
                const bottom_edge: usize = y;
                std.debug.print("Tube from {}/{} to {}/{}\n", .{ x, top_edge, x, bottom_edge });
                var tube: Game.Tube = undefined;
                tube.tap_position = .{ .x = x, .y = (top_edge + bottom_edge) / 2 };
                for (0..4) |segment_idx| {
                    const segment_y_center: usize = top_edge + (2 * segment_idx + 1) * (bottom_edge - top_edge) / 8;
                    var segment_color: u24 = rgb(img, x, segment_y_center);
                    if (is_bg_color(segment_color)) {
                        segment_color = 0;
                    } else {
                        for (tubes.items) |t| {
                            for (0..4) |i| {
                                if (colors_are_similar(segment_color, t.segments[i])) {
                                    segment_color = t.segments[i];
                                }
                            }
                        }
                    }
                    for (0..segment_idx) |i| {
                        if (colors_are_similar(segment_color, tube.segments[i])) {
                            segment_color = tube.segments[i];
                        }
                    }
                    tube.segments[segment_idx] = segment_color;
                    std.debug.print("{}/{}:\t#{x:06}\n", .{ x, segment_y_center, tube.segments[segment_idx] });
                }
                try tubes.append(alloc, tube);
                x = x_continue_search;
                y = (top_edge + bottom_edge) / 2;
            }
        }
    }

    for (tubes.items) |t| {
        for (0..4) |i| {
            const color: u24 = t.segments[i];
            var color_count: usize = 0;
            for (tubes.items) |t2| {
                for (0..4) |j| {
                    if (color == t2.segments[j]) {
                        color_count += 1;
                    }
                }
            }
            // std.debug.print("color #{x:06} occurs {} times\n", .{ color, color_count });
            if (color == 0) {
                std.debug.assert(color_count == 8); // exactly 8 empty segments
            } else {
                std.debug.assert(color_count == 4); // each color occurs exactly 4 times
            }
        }
    }

    return Game.init(alloc, try tubes.toOwnedSlice(alloc));
}

// test "basic add functionality" {
//     try std.testing.expect(add(3, 7) == 10);
// }
