const std = @import("std");
const offu = @import("offu");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Memory leak");
    }

    var ufo = try offu.init("test_inputs/Untitled.ufo", allocator, .{});
    defer ufo.deinit(allocator);

    try ufo.validate();

    std.log.info("UFO Version: {d}", .{ufo.meta_info.format_version});
    std.log.info("Previous UFO Creator: {s}", .{ufo.meta_info.creator.?});
    ufo.meta_info.updateCreator();
    std.log.info("Current UFO Creator: {s}", .{ufo.meta_info.creator.?});
}
