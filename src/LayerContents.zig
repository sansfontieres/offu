//! Representation of [layercontents.plist]
//!
//! This file maps the layer names to the glyph directory names. This
//! file is required for a valid UFO.
//!
//! [layercontents.plist]: https://unifiedfontobject.org/versions/ufo3/layercontents.plist/

/// A list of Layers, the first one being the default layer. The list
/// MUST NOT be empty.
pub const LayerContents = @This();

layers: std.MultiArrayList(Layer),

const Error = error{
    DuplicateLayer,
    EmptyLayerContents,
};

/// Returns the default layer from LayerContents, which is always the
/// first layer defined in layercontents.plist
pub fn getDefaultLayer(self: *LayerContents) !Layer {
    if (self.layers.len == 0) return Error.EmptyLayerContents;

    return self.layers.get(0);
}

/// This file is built in a weird way. Instead of having an array of
/// dicts, it holds arrays of arrays of strings, the first being the
/// name, the last being the path directory.
pub fn initFromDoc(doc: xml.Doc, allocator: std.mem.Allocator) !LayerContents {
    const root_node = try doc.getRootElement();

    const layers = try root_node.arrayToSoa(allocator, Layer);

    var layer_contents: LayerContents = .{ .layers = layers };
    try layer_contents.validate(allocator);

    return layer_contents;
}

pub fn deinit(self: *LayerContents, allocator: std.mem.Allocator) void {
    while (true) {
        var layer: ?Layer = undefined;
        layer = self.layers.popOrNull();
        if (layer) |*l| l.deinit() else break;
    }

    self.layers.deinit(allocator);
}

// Feels like a duplicate of validate...
pub fn append(self: *LayerContents, allocator: std.mem.Allocator, layer: Layer) !void {
    if (self.layers.len == 0) {
        self.layers.append(allocator, layer);
        return;
    }

    var names = std.StringHashMapUnmanaged(void){};
    defer names.deinit(allocator);

    var paths = std.StringHashMapUnmanaged(void){};
    defer paths.deinit(allocator);

    for (self.layers.items(.name), self.layers.items(.path)) |name, path| {
        try names.putNoClobber(allocator, name, {});
        try paths.putNoClobber(allocator, path, {});
    }

    try names.putNoClobber(allocator, layer.name, {}) catch {
        logger.err("This layer name is a duplicate: {s}", .{layer.name});
        return Error.DuplicateLayer;
    };

    try paths.putNoClobber(allocator, layer.path, {}) catch {
        logger.err("This layer path is a duplicate: {s}", .{layer.path});
        return Error.DuplicateLayer;
    };
}

pub fn validate(self: *LayerContents, allocator: std.mem.Allocator) !void {
    if (self.layers.len == 0) return Error.EmptyLayerContents;

    var names = std.StringHashMapUnmanaged(void){};
    defer names.deinit(allocator);

    var paths = std.StringHashMapUnmanaged(void){};
    defer paths.deinit(allocator);

    for (self.layers.items(.name), self.layers.items(.path)) |name, path| {
        names.putNoClobber(allocator, name, {}) catch {
            logger.err("This layer name is a duplicate: {s}", .{name});
            return Error.DuplicateLayer;
        };

        paths.putNoClobber(allocator, path, {}) catch {
            logger.err("This layer path is a duplicate: {s}", .{path});
            return Error.DuplicateLayer;
        };
    }
}

const std = @import("std");
const xml = @import("xml.zig");
const logger = @import("Logger.zig").scopped(.LayerContents);
const Layer = @import("Layer.zig");

pub const layer_contents_file = "layercontents.plist";

test "initFromDoc" {
    const test_allocator = std.testing.allocator;

    var doc = try xml.Doc.fromFile("test_inputs/Untitled.ufo/layercontents.plist");
    defer doc.deinit();

    var layer_contents = try initFromDoc(doc, test_allocator);
    defer layer_contents.deinit(test_allocator);

    try std.testing.expectEqualStrings("foreground", layer_contents.layers.get(0).name);
    try std.testing.expectEqualStrings("glyphs", layer_contents.layers.get(0).path);
    try std.testing.expectEqualStrings("background", layer_contents.layers.get(1).name);
    try std.testing.expectEqualStrings("glyphs.background", layer_contents.layers.get(1).path);
}

test "getDefaultLayer returns the correct layer" {
    const test_allocator = std.testing.allocator;

    var doc = try xml.Doc.fromFile("test_inputs/Untitled.ufo/layercontents.plist");
    defer doc.deinit();

    var layer_contents = try initFromDoc(doc, test_allocator);
    defer layer_contents.deinit(test_allocator);

    const default_layer = try layer_contents.getDefaultLayer();
    try std.testing.expectEqualStrings("foreground", default_layer.name);
}
