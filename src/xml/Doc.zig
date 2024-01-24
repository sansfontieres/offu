pub const Doc = @This();

const std = @import("std");
const libxml2 = @import("../libxml2.zig");
const logger = std.log.scoped(.xml);

ptr: *libxml2.xmlDoc,

pub const FormatType = enum {
    plist,
    glif,
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
    ) orelse return Error.ReadFile;

    return Doc{
        .ptr = doc,
    };
}

pub fn deinit(doc: *Doc) void {
    libxml2.xmlFreeDoc(doc.ptr);
}

pub fn getRootElement(doc: Doc) !Node {
    const root_element = libxml2.xmlDocGetRootElement(doc.ptr) orelse {
        return Error.NoRoot;
    };

    const root_name = std.mem.span(root_element.*.name);

    _ = std.meta.stringToEnum(FormatType, root_name) orelse {
        logger.err("Document is an unknown format: {s}", .{root_name});
        return Error.WrongFile;
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

        if (content.len == 0) return null;

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

    pub fn iterateDict(
        dict: Node,
    ) DictIterator {
        // Jump to the first key
        const node = dict.findChild("key");
        return DictIterator{
            .node = node.?,
        };
    }
};

test "iteracteDict iterates through plist elements only" {
    var doc = try Doc.fromFile("test_inputs/Untitled.ufo/metainfo.plist");
    defer doc.deinit();

    var node: ?Node = try doc.getRootElement();
    node = node.?.findChild("dict");

    var node_it = node.?.iterateDict();
    while (node_it.next()) |element| {
        try std.testing.expect(element.getElementType() == .element);
    }
}
