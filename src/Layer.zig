//! Representation of a glyph layer from `LayerContents`,
//! [layerinfo.plist] and [contents.plist]
//!
//! A layerinfo.plist file per layer SHOULD exist and defines some
//! properties for a `Layer`. All of its content is optional.
//!
//! contents.plist is a map between a glyph name and the corresponding
//! *.glif.
//!
//! [contents.plist]: https://unifiedfontobject.org/versions/ufo3/glyphs/contents.plist/
//! [layerinfo.plist]: https://unifiedfontobject.org/versions/ufo3/glyphs/layerinfo.plist/
pub const Layer = @This();

glyphs: std.StringHashMap(Glif),

/// The name of the layer, must be unique.
/// Extracted from layercontents.plist.
name: []const u8,

/// The directory of the layer, a string representing a path
/// relative to the root of a given UFO. Must start with
/// “glyph.”.
/// Extracted from layercontents.plist.
path: []const u8,

/// The color that should be used for all glyphs in the layer.
/// Extracted from layerinfo.plist.
color: ?Color = null,

// TODO: lib and their arbitrary structures ?
// lib: ?Lib = null,

pub const PathInitArgs = struct {
    name: []const u8,
    root: []const u8,
    dirname: []const u8,
};

pub fn deinit(self: *Layer) void {
    var glyphs_it = self.glyphs.valueIterator();
    while (glyphs_it.next()) |glif| {
        glif.deinit();
    }
    self.glyphs.deinit();

    logger.debug("{} was successfully deinited", .{Layer});
}

/// Init from a set of arguments extracted from layercontents.plist
pub fn init(allocator: std.mem.Allocator, args: PathInitArgs) !Layer {
    const layer_info_path = try std.fs.path.join(allocator, &[_][]const u8{
        args.root,
        args.dirname,
        layer_info_file,
    });
    defer allocator.free(layer_info_path);

    const contents_path = try std.fs.path.join(allocator, &[_][]const u8{
        args.root,
        args.dirname,
        contents_file,
    });
    defer allocator.free(contents_path);

    var glyphs = std.StringHashMap(Glif).init(allocator);
    var color: ?Color = undefined;

    // This file is optional
    var layer_info_doc: ?xml.Doc = xml.Doc.fromFile(layer_info_path) catch null;

    // TODO: handle lib dict with some skeleton struct
    if (layer_info_doc) |*d| {
        defer d.deinit();
        color = try Color.fromLayerInfo(d.*);
    }

    var contents_doc = try xml.Doc.fromFile(contents_path);
    defer contents_doc.deinit();
    const contents_doc_root = try contents_doc.getRootElement();
    const dict = contents_doc_root.findChild("dict") orelse return Error.MalformedFile;

    var contents = try contentsFromDoc(allocator, dict);
    defer contents.deinit();

    var contents_it = contents.keyIterator();
    while (contents_it.next()) |content| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{
            args.root,
            args.dirname,
            content.path,
        });
        defer allocator.free(full_path);

        const glif = try Glif.fromContent(.{ .name = content.name, .path = full_path }, allocator);
        try glyphs.putNoClobber(content.name, glif);
    }

    return .{
        .glyphs = glyphs,
        .name = args.name,
        .path = args.dirname,
        .color = color,
    };
}

/// Given a XML dict, stores the KVs of the dict into an HashMap to make
/// sure that each pairs are unique
pub fn contentsFromDoc(allocator: std.mem.Allocator, dict: xml.Node) !ContentHashList {
    var contents = ContentHashList.init(allocator);

    var node_it = dict.iterateDict() catch |e| {
        switch (e) {
            xml.Node.Error.NoDictKey => {
                logger.info("No glyphs were found", .{});
                return contents;
            },
            else => return e,
        }
    };

    while (node_it.next()) |xml_field| {
        const value_node = node_it.next() orelse return xml.Node.Error.NoValue;
        const value_content = value_node.getContent() orelse return xml.Node.Error.EmptyElement;
        const field_content = xml_field.getContent() orelse return xml.Node.Error.EmptyElement;

        try contents.putNoClobber(.{ .name = field_content, .path = value_content }, {});
    }

    return contents;
}

pub const Error = error{
    MalformedFile,
};

pub const Content = struct {
    path: []const u8,
    name: []const u8,

    pub const Context = struct {
        pub fn hash(_: Context, key: Content) u64 {
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, key, .Deep);

            return hasher.final();
        }

        pub fn eql(_: Context, a: Content, b: Content) bool {
            return std.mem.eql(u8, a.name, b.name) or std.mem.eql(u8, a.path, b.path);
        }
    };
};

const ContentHashList = std.HashMap(
    Content,
    void,
    Content.Context,
    std.hash_map.default_max_load_percentage,
);

const std = @import("std");
const xml = @import("xml.zig");

const logger = @import("Logger.zig").scopped(.Layer);

const Glif = @import("Glif.zig");
const Color = @import("Color.zig");

pub const layer_info_file = "layerinfo.plist";
pub const contents_file = "contents.plist";
