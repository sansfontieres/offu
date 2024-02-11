//! A wrapper around libxml2’s xmlDoc
pub const Doc = @This();

ptr: *libxml2.xmlDoc,

/// List of format types that Offu accepts
pub const FormatType = enum {
    plist,
    glyph, // .glif files
};

pub const Error = error{
    NoRoot,
    ReadFile,
    WrongFile,
};

/// Given a string path, returns a Doc, a wrapper around xmlDocPtr
pub fn fromFile(path: []const u8) !Doc {
    var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const final_path = try std.fmt.bufPrint(buffer[0..], "{s}\u{0}", .{path});

    const doc = libxml2.xmlReadFile(final_path.ptr, "utf-8", 0) orelse {
        logger.err("Could not read file: {s}", .{path});
        return Error.ReadFile;
    };

    logger.info("{s} was loaded sucessfully", .{path});
    return Doc{ .ptr = doc };
}

/// Given a node, returns the Docs it came from
pub fn fromNode(node: Node) Doc {
    const xml_doc = node.ptr.*.doc;
    return Doc{ .ptr = xml_doc };
}

pub fn deinit(doc: *Doc) void {
    libxml2.xmlFreeDoc(doc.ptr);

    logger.debug("{} was successfully deinited", .{Doc});
}

/// Wraps lixbml2.xmlDocGetRootElement
pub fn getRootElement(doc: Doc) !Node {
    const root_element = libxml2.xmlDocGetRootElement(doc.ptr) orelse return Error.NoRoot;

    const root_name = std.mem.span(root_element.*.name);

    _ = std.meta.stringToEnum(FormatType, root_name) orelse {
        logger.err("Document is an unknown format: {s}", .{root_name});
        return Error.WrongFile;
    };

    logger.debug("Found root element: {s}", .{root_name});
    return Node{ .ptr = root_element };
}

/// Returns the URL of the file of the current Doc
pub fn getUrl(doc: Doc) []const u8 {
    return std.mem.span(doc.ptr.URL);
}

// HINT: Maybe we should just store the path in the struct.
/// Returns the path of the file of the current Doc
pub fn getPath(doc: Doc, allocator: std.mem.Allocator) ![]const u8 {
    return try std.Uri.unescapeString(allocator, doc.getUrl());
}

const std = @import("std");
const libxml2 = @import("../libxml2.zig");
const logger = @import("../Logger.zig").scopped(.@"xml Doc");
const Node = @import("Node.zig");
