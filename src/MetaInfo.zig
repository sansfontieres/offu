//! Representation of [metainfo.plist]
//!
//! This file contains metadata about the UFO. This file is required and
//! so is MetaInfo
//!
//! [metainfo.plist]: https://unifiedfontobject.org/versions/ufo3/metainfo.plist/
const MetaInfo = @This();

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
pub fn validate(self: *MetaInfo) !void {
    // We only support UFO3
    if (self.format_version != 3) {
        logger.err("formatVersion is not 3: {d}", .{self.format_version});
        return Error.WrongVersionMajor;
    }
    if (self.format_version_minor) |format_version_minor| {
        if (format_version_minor == 0) {
            logger.info("formatVersionMinor is optional if set to 0", .{});
        }
    }

    logger.info("{} is valid", .{MetaInfo});
}

// This is medieval
pub fn initFromDoc(doc: *xml.Doc, allocator: std.mem.Allocator) !MetaInfo {
    const root_node = try doc.getRootElement();
    const dict: ?xml.Node = root_node.findChild("dict") orelse {
        return Error.MalformedFile;
    };

    var meta_info = try dict.?.xmlDictToStruct(allocator, MetaInfo);

    // We replace the creator field with our own since we are the last
    // authoring tool touching this UFO
    meta_info.creator = meta_info_default_creator;

    return meta_info;
}

const std = @import("std");
pub const xml = @import("xml.zig");
const logger = @import("Logger.zig").scopped(.metainfo);

const MetaInfoEnum = std.meta.FieldEnum(MetaInfo);
const meta_info_default_creator = "com.sansfontieres.offu";

test "deserialize" {
    const test_allocator = std.testing.allocator;

    var doc = try xml.Doc.fromFile("test_inputs/Untitled.ufo/metainfo.plist");
    defer doc.deinit();

    var meta_info = try initFromDoc(&doc, test_allocator);

    try std.testing.expectEqualStrings(
        meta_info_default_creator,
        meta_info.creator.?,
    );
    try std.testing.expectEqual(3, meta_info.format_version);
    try std.testing.expectEqual(null, meta_info.format_version_minor);

    try meta_info.validate();
}
