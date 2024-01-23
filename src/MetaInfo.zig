//! Representation of [metainfo.plist]
//!
//! This file contains metadata about the UFO. This file is required and
//! so is MetaInfo
//!
//! [metainfo.plist]: https://unifiedfontobject.org/versions/ufo3/metainfo.plist/
const MetaInfo = @This();

const std = @import("std");
const Xml = @import("Xml.zig");

const MetaInfoEnum = std.meta.FieldEnum(MetaInfo);
const meta_info_default_creator = "com.sansfontieres.offu";

/// The application or library that created the UFO. This should follow
/// a reverse domain naming scheme. For example, org.robofab.ufoLib.
creator: ?[]const u8 = meta_info_default_creator,

/// The major version number of the UFO format. 3 for UFO 3. Required.
/// (and we only support UFO3 here)
format_version: usize = undefined,

/// Optional if 0
format_version_minor: ?usize = null,

const Error = error{
    MalformedFile,
    WrongFile,
};

// This is medieval
pub fn nodeToField(
    self: *MetaInfo,
    key_node: Xml.Node,
    value_node: Xml.Node,
) !void {
    const key = key_node.getContent() orelse return Xml.Error.EmptyElement;

    // We recognize that this key/value exists, but we will replace
    // it with meta_info_default_creator
    if (std.mem.eql(u8, key, "creator")) return;

    const value = value_node.getContent() orelse return Xml.Error.EmptyElement;

    if (std.mem.eql(u8, key, "formatVersion")) {
        self.format_version = try std.fmt.parseInt(usize, value, 10);
    } else {
        return error.UnknownField;
    }
}

// This is medieval
pub fn initFromDoc(doc: *Xml) !MetaInfo {
    const root_node = try doc.getRootElement();

    if (!std.mem.eql(u8, root_node.getName(), "plist")) {
        return Error.WrongFile;
    }

    const dict: ?Xml.Node = root_node.findChild("dict") orelse {
        return Error.MalformedFile;
    };

    var meta_info = MetaInfo{};

    var node_it = dict.?.iterateDict();
    while (node_it.next()) |element| {
        try meta_info.nodeToField(
            element,
            node_it.next() orelse return Xml.Error.NoValue,
        );
    }

    return meta_info;
}

test "deserialize" {
    var doc = try Xml.fromFile("test_inputs/Untitled.ufo/metainfo.plist");
    defer doc.deinit();
    const meta_info = try initFromDoc(&doc);
    try std.testing.expectEqualStrings(
        meta_info_default_creator,
        meta_info.creator.?,
    );
    try std.testing.expectEqual(3, meta_info.format_version);
    try std.testing.expectEqual(null, meta_info.format_version_minor);
}
