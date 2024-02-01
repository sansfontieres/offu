//! A wrapper around libxml2 xmlDoc
pub const Doc = @This();

ptr: *libxml2.xmlDoc,

pub const FormatType = enum {
    plist,
    glyph, // .glif files
};

pub const Error = error{
    NoRoot,
    ReadFile,
    WrongFile,
};

pub fn fromFile(path: []const u8) !Doc {
    const doc = libxml2.xmlReadFile(
        path.ptr,
        "utf-8",
        0,
    ) orelse return Error.ReadFile;

    logger.info("Loaded {s} sucessfully", .{path});
    return Doc{
        .ptr = doc,
    };
}

pub fn deinit(doc: *Doc) void {
    libxml2.xmlFreeDoc(doc.ptr);

    logger.debug("Deinited {} successfully", .{Doc});
}

/// Wraps lixbml2.xmlDocGetRootElement
pub fn getRootElement(doc: Doc) !Node {
    const root_element = libxml2.xmlDocGetRootElement(doc.ptr) orelse {
        return Error.NoRoot;
    };
    const root_name = std.mem.span(root_element.*.name);
    _ = std.meta.stringToEnum(FormatType, root_name) orelse {
        logger.err("Document is an unknown format: {s}", .{root_name});
        return Error.WrongFile;
    };

    logger.debug("Found root element: {s}", .{root_name});
    return Node{
        .ptr = root_element,
    };
}

/// Returns the path of the file of the current Doc
pub fn getUrl(doc: Doc) []const u8 {
    return std.mem.span(doc.ptr.URL);
}

const std = @import("std");
const libxml2 = @import("../libxml2.zig");
const logger = @import("../Logger.zig").scopped(.xml_doc);
const Node = @import("Node.zig");
