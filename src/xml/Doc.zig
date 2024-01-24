pub const Doc = @This();

const std = @import("std");
const libxml2 = @import("../libxml2.zig");

ptr: *libxml2.xmlDoc,

pub const Error = error{
    EmptyElement,
    NoRoot,
    ReadFile,
    WrongFile,
} || std.fmt.ParseIntError;

pub fn fromFile(path: []const u8) !Doc {
    return Doc{
        .ptr = libxml2.xmlReadFile(
            path.ptr,
            "utf-8",
            0,
        ) orelse return Error.ReadFile,
    };
}

pub fn deinit(doc: *Doc) void {
    libxml2.xmlFreeDoc(doc.ptr);
}

pub fn getRootElement(doc: Doc) !Node {
    return Node{
        .ptr = libxml2.xmlDocGetRootElement(doc.ptr) orelse {
            return Error.NoRoot;
        },
    };
}

pub const Node = struct {
    ptr: *libxml2.xmlNode,

    pub const Error = error{
        NoValue,
    };

    pub fn findNextElem(node: Node) ?Node {
        var it = @as(?*libxml2.xmlNode, @ptrCast(node.ptr.next));
        while (it != null) : (it = it.?.next) {
            if (it.?.type == 1) return Node{ .ptr = it.? };
        }

        return null;
    }

    pub fn findChild(node: Node, key: []const u8) ?Node {
        var it = @as(?*libxml2.xmlNode, @ptrCast(node.ptr.children));
        while (it != null) : (it = it.?.next) {
            if (it.?.type != 1)
                continue;

            const name = std.mem.span(it.?.name orelse continue);
            if (std.mem.eql(u8, key, name)) return Node{ .ptr = it.? };
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

    // TODO: Create an ArrayIterator for .plist
    // TODO: Create an AttrIterator for .glif
    // TODO: Handle nested Dict
    pub const DictIterator = struct {
        node: ?Node,

        pub fn next(it: *DictIterator) ?Node {
            while (it.node) |node| {
                if (node.ptr.type != 1) continue;

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
