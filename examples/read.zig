const std = @import("std");
const offu = @import("offu");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Memory leak");
    }

    var ufo_path: []const u8 = undefined;

    if (std.os.argv.len == 2) {
        ufo_path = std.mem.span(std.os.argv[1]);
    } else {
        ufo_path = "test_inputs/Untitled.ufo";
    }

    var ufo = try offu.init(ufo_path, allocator, .{});
    defer ufo.deinit(allocator);

    try ufo.validate();

    std.log.info("UFO Version: {d}", .{ufo.meta_info.format_version});
    std.log.info("Previous UFO Creator: {s}", .{ufo.meta_info.creator.?});
    ufo.meta_info.updateCreator();
    std.log.info("Current UFO Creator: {s}", .{ufo.meta_info.creator.?});

    var glif_count: usize = 0;
    const layers = ufo.layer_contents.layers;

    std.log.info("This UFO have {} layers", .{layers.len});

    for (layers.items(.glyphs), layers.items(.name)) |glyphs, name| {
        const glyphs_count = glyphs.count();
        glif_count += glyphs_count;
        std.log.info("Layer {s} have {d} glifs", .{ name, glyphs_count });
    }

    std.log.info("Accross layers, there is {d} glifs", .{glif_count});

    for (layers.items(.glyphs), layers.items(.name)) |glyphs, name| {
        std.log.info("Layer {s} have the following glifs:", .{name});
        var glyphs_it = glyphs.valueIterator();

        while (glyphs_it.next()) |glif| {
            var codepoint_it = glif.codepoints.keyIterator();
            const first_codepoint = codepoint_it.next();

            if (first_codepoint) |cp| {
                std.log.info(
                    "{s} (U+{X}) | width: {d}, height: {d}",
                    .{ glif.name, cp.*, glif.advance.width, glif.advance.height },
                );
            } else std.log.info(
                "{s} (no codepoint) | width: {d}, height: {d}",
                .{ glif.name, glif.advance.width, glif.advance.height },
            );
        }
    }
}
