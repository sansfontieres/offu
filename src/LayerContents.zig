//! Representation of [layercontents.plist]
//!
//! This file maps the layer names to the glyph directory names. This
//! file is required for a valid UFO.
//!
//! [layercontents.plist]: https://unifiedfontobject.org/versions/ufo3/layercontents.plist/

/// A list of Layers, the first one being the default layer.
/// The list MUST NOT be empty.
pub const LayerContents = @This();

layers: std.MultiArrayList(Layer),

pub const Layer = struct {
    /// The name of the layer, must be unique
    name: []const u8,

    /// The directory of the layer, a string representing a path
    /// relative to the root of a given UFO. Must start with
    /// “glyph.”
    directory: []const u8,
};

/// This file is built in a weird way. Instead of having an array of
/// dicts, it holds arrays of arrays of strings, the first being the
/// name, the last being the directory.
pub fn initFromDoc(doc: *xml.Doc, allocator: std.mem.Allocator) !LayerContents {
    const root_node = try doc.getRootElement();
    var layer_contents = LayerContents{ .layers = std.MultiArrayList(Layer){} };

    const array_of_raw_layers = try root_node.xmlArrayToArray(
        allocator,
        std.ArrayList([]const u8),
    );
    defer array_of_raw_layers.deinit();

    for (array_of_raw_layers.items) |raw_layer| {
        defer raw_layer.deinit();
        try layer_contents.layers.append(
            allocator,
            .{
                .name = raw_layer.items[0],
                .directory = raw_layer.items[1],
            },
        );
    }

    return layer_contents;
}

pub fn deinit(layer_content: *LayerContents, allocator: std.mem.Allocator) void {
    layer_content.layers.deinit(allocator);
}

const std = @import("std");
const xml = @import("xml.zig");
const logger = @import("Logger.zig").scopped(.layercontents);
const Glif = @import("Glif.zig");

test "initFromDoc" {
    const test_allocator = std.testing.allocator;

    var doc = try xml.Doc.fromFile("test_inputs/Untitled.ufo/layercontents.plist");
    defer doc.deinit();

    var layer_contents = try initFromDoc(&doc, test_allocator);
    defer layer_contents.deinit(test_allocator);

    try std.testing.expectEqualStrings(
        "foreground",
        layer_contents.layers.get(0).name,
    );

    try std.testing.expectEqualStrings(
        "glyphs",
        layer_contents.layers.get(0).directory,
    );

    try std.testing.expectEqualStrings(
        "background",
        layer_contents.layers.get(1).name,
    );

    try std.testing.expectEqualStrings(
        "glyphs.background",
        layer_contents.layers.get(1).directory,
    );
}
