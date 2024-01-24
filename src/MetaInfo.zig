//! Representation of [metainfo.plist]
//!
//! This file contains metadata about the UFO. This file is required and
//! so is MetaInfo
//!
//! [metainfo.plist]: https://unifiedfontobject.org/versions/ufo3/metainfo.plist/
const MetaInfo = @This();

const std = @import("std");
pub const xml = @import("xml/main.zig");
const logger = @import("../logger.zig").Logger(.metainfo);

const MetaInfoEnum = std.meta.FieldEnum(MetaInfo);
const meta_info_default_creator = "com.sansfontieres.offu";

/// The application or library that created the UFO. This should follow
/// a reverse domain naming scheme. For example, org.robofab.ufoLib.
creator: ?[]const u8 = meta_info_default_creator,

/// The major version number of the UFO format. Required.
format_version: usize = undefined,

/// Optional if 0
format_version_minor: ?usize = null,

const Error = error{
    MalformedFile,

    WrongVersionMajor,
};

/// Checks if fields, when not null, are correctly defined per the UFO
/// specification
pub fn verification(self: *MetaInfo) !bool {
    // We only support UFO3
    if (self.format_version != 3) {
        logger.err("formatVersion is not 3: {d}", .{self.format_version});
        return Error.WrongVersionMajor;
    }
    if (self.format_version_minor) |format_version_minor| {
        if (format_version_minor == 0) {
            logger.warn("formatVersionMinor is optional if set to 0", .{});
        }
    }

    return true;
}

// This is medieval
pub fn nodeToField(
    self: *MetaInfo,
    key_node: xml.Doc.Node,
    value_node: xml.Doc.Node,
) !void {
    const key = key_node.getContent() orelse return xml.Doc.Error.EmptyElement;

    // We recognize that this key/value exists, but we will replace
    // it with meta_info_default_creator
    if (std.mem.eql(u8, key, "creator")) return;

    const value = value_node.getContent() orelse return xml.Doc.Error.EmptyElement;

    if (std.mem.eql(u8, key, "formatVersion")) {
        self.format_version = try std.fmt.parseInt(usize, value, 10);
    } else {
        return error.UnknownField;
    }
}

// This is medieval
pub fn initFromDoc(doc: *xml.Doc) !MetaInfo {
    const root_node = try doc.getRootElement();

    const dict: ?xml.Doc.Node = root_node.findChild("dict") orelse {
        return Error.MalformedFile;
    };

    var meta_info = MetaInfo{};

    var node_it = dict.?.iterateDict();
    while (node_it.next()) |element| {
        try meta_info.nodeToField(
            element,
            node_it.next() orelse return xml.Doc.Node.Error.NoValue,
        );
    }

    return meta_info;
}

test "deserialize" {
    var doc = try xml.Doc.fromFile("test_inputs/Untitled.ufo/metainfo.plist");
    defer doc.deinit();
    var meta_info = try initFromDoc(&doc);
    try std.testing.expectEqualStrings(
        meta_info_default_creator,
        meta_info.creator.?,
    );
    try std.testing.expectEqual(3, meta_info.format_version);
    try std.testing.expectEqual(null, meta_info.format_version_minor);

    _ = try meta_info.verification();
}
