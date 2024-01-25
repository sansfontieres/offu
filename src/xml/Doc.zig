pub const Doc = @This();

const std = @import("std");
const libxml2 = @import("../libxml2.zig");
const logger = @import("../logger.zig").Logger(.xml);

ptr: *libxml2.xmlDoc,

pub const FormatType = enum {
    plist,
    glyph, // .glif files
};

pub const Error = error{
    EmptyElement,
    NoRoot,
    ReadFile,
    WrongFile,
} || std.fmt.ParseIntError;

pub fn fromFile(path: []const u8) !Doc {
    const doc = libxml2.xmlReadFile(
        path.ptr,
        "utf-8",
        0,
    ) orelse return Doc.Error.ReadFile;

    return Doc{
        .ptr = doc,
    };
}

pub fn deinit(doc: *Doc) void {
    libxml2.xmlFreeDoc(doc.ptr);
}

pub fn getRootElement(doc: Doc) !Node {
    const root_element = libxml2.xmlDocGetRootElement(doc.ptr) orelse {
        return Doc.Error.NoRoot;
    };
    const root_name = std.mem.span(root_element.*.name);
    _ = std.meta.stringToEnum(FormatType, root_name) orelse {
        logger.err("Document is an unknown format: {s}", .{root_name});
        return Doc.Error.WrongFile;
    };

    return Node{
        .ptr = root_element,
    };
}

pub const Node = struct {
    ptr: *libxml2.xmlNode,

    pub const ElementType = enum(c_uint) {
        element = 1,
        attribute = 2,
        text = 3,
        cdata_section = 4,
        entity_ref = 5,
        entity = 6,
        pi = 7,
        comment = 8,
        document = 9,
        document_type = 10,
        document_frag = 11,
        notation = 12,
        html_document = 13,
        dtd = 14,
        element_decl = 15,
        attribute_decl = 16,
        entity_decl = 17,
        namespace_decl = 18,
        xinclude_start = 19,
        xinclude_end = 20,
    };

    pub const Error = error{
        NotAStruct,
        NoValue,
    };

    pub fn findNextElem(node: Node) ?Node {
        var it = @as(?*libxml2.xmlNode, @ptrCast(node.ptr.next));
        while (it != null) : (it = it.?.next) {
            const next_element = Node{ .ptr = it.? };
            if (next_element.getElementType() == .element) return next_element;
        }

        return null;
    }

    pub fn findChild(node: Node, key: []const u8) ?Node {
        var it = @as(?*libxml2.xmlNode, @ptrCast(node.ptr.children));
        while (it != null) : (it = it.?.next) {
            const child_node = Node{ .ptr = it.? };
            if (child_node.getElementType() != .element) continue;

            if (std.mem.eql(u8, key, child_node.getName())) {
                return child_node;
            }
        }
        return null;
    }

    pub fn getContent(node: Node) ?[]const u8 {
        const content = std.mem.span(libxml2.xmlNodeGetContent(node.ptr));

        if (std.mem.eql(u8, content, "\u{0}")) return null;

        return content;
    }

    pub fn getName(node: Node) []const u8 {
        return std.mem.span(node.ptr.name);
    }

    pub fn getElementType(node: Node) ?ElementType {
        return @enumFromInt(node.ptr.type);
    }

    // TODO: Create an ArrayIterator for .plist
    // TODO: Create an AttrIterator for .glif
    // TODO: Handle nested Dict
    pub const DictIterator = struct {
        node: ?Node,

        pub fn next(it: *DictIterator) ?Node {
            while (it.node) |node| {
                if (node.getElementType() != .element) continue;

                const ret = node;
                var next_node: ?Node = null;
                next_node = node.findNextElem();
                it.node = next_node;
                return ret;
            }
            return null;
        }
    };

    pub fn iterateDict(dict: Node) DictIterator {
        // Jump to the first key
        const node = dict.findChild("key");
        return DictIterator{
            .node = node.?,
        };
    }

    // This is medieval
    /// Given a XML dict and a struct, maps the dict values into the
    /// fields of a struct, following the given key name mapping.
    pub fn dictToStruct(
        dict: Node,
        allocator: std.mem.Allocator,
        comptime T: anytype,
        key_map: std.StringHashMap([]const u8),
    ) !T {
        var t = T{};

        var node_it = dict.iterateDict();
        var dict_hm = std.StringHashMap([]const u8).init(allocator);
        defer dict_hm.deinit();

        while (node_it.next()) |xml_field| {
            const value = node_it.next() orelse return Node.Error.NoValue;

            const field_content = xml_field.getContent() orelse {
                return Doc.Error.EmptyElement;
            };

            const value_content = value.getContent() orelse {
                return Doc.Error.EmptyElement;
            };

            if (key_map.get(field_content)) |key| {
                try dict_hm.put(key, value_content);
            }
        }

        const type_info = @typeInfo(T);

        // TODO: 😾
        switch (type_info) {
            .Struct => |structInfo| {
                inline for (structInfo.fields) |field| {
                    if (dict_hm.get(field.name)) |raw_value| {
                        @field(t, field.name) = try parseForStructField(
                            field,
                            raw_value,
                        );
                    }
                }
            },
            else => return Node.Error.NotAStruct,
        }
        return t;
    }

    /// An internal function called recursively by dictToStruct to parse a
    /// string into the type of a struct field.
    pub fn parseForStructField(
        field: anytype,
        raw_value: []const u8,
    ) !field.type {
        // TODO: Fill that with more types
        switch (field.type) {
            usize, ?usize => {
                return try std.fmt.parseInt(
                    usize,
                    raw_value,
                    10,
                );
            },
            else => return raw_value,
        }
    }
};

test "getRootElement returns a Node only for known format types" {
    var plist = try Doc.fromFile("test_inputs/Untitled.ufo/metainfo.plist");
    defer plist.deinit();
    _ = try plist.getRootElement();

    var glif = try Doc.fromFile("test_inputs/space.glif");
    defer glif.deinit();
    _ = try glif.getRootElement();

    var unknown_format = try Doc.fromFile("test_inputs/simple_xml.xml");
    defer unknown_format.deinit();
    try std.testing.expectError(
        Doc.Error.WrongFile,
        unknown_format.getRootElement(),
    );
}

test "iteracteDict iterates through plist elements only" {
    var doc = try Doc.fromFile("test_inputs/Untitled.ufo/metainfo.plist");
    defer doc.deinit();

    const root_node: ?Node = try doc.getRootElement();
    var node = root_node.?.findChild("dict") orelse {
        return error.MalformedFile;
    };

    var node_it = node.iterateDict();
    while (node_it.next()) |element| {
        try std.testing.expect(element.getElementType() == .element);
    }
}

test "dictToStruct" {
    const MetaInfo = @import("../MetaInfo.zig");
    const test_allocator = std.testing.allocator;

    var doc = try Doc.fromFile("test_inputs/Untitled.ufo/metainfo.plist");
    defer doc.deinit();

    var node: ?Node = try doc.getRootElement();
    node = node.?.findChild("dict").?;

    // TODO: tidy key_map creation
    var key_map = std.StringHashMap([]const u8).init(test_allocator);
    try key_map.put("creator", "creator");
    try key_map.put("formatVersion", "format_version");
    try key_map.put("formatVersionMinor", "format_version_minor");
    defer key_map.deinit();

    _ = try node.?.dictToStruct(
        test_allocator,
        MetaInfo,
        key_map,
    );
}
