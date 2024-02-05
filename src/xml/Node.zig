//! A wrapper around libxml2’s xmlNode
pub const Node = @This();

ptr: *libxml2.xmlNode,

/// Representation of an xmlNode.type
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
    EmptyElement,
    NoDictKey,
    NoValue,
    UnknownFieldType,
    UnknownKey,
    UnknownValue,
};

/// Returns the next xmlNode Element
pub fn findNextElem(node: Node) ?Node {
    var it = @as(?*libxml2.xmlNode, @ptrCast(node.ptr.next));
    while (it != null) : (it = it.?.next) {
        const next_element = Node{ .ptr = it.? };
        if (next_element.getElementType() == .element) return next_element;
    }

    return null;
}

/// Returns the next child xmlNode Element (name optionnally specified)
pub fn findChild(node: Node, key: ?[]const u8) ?Node {
    var it = @as(?*libxml2.xmlNode, @ptrCast(node.ptr.children));
    while (it != null) : (it = it.?.next) {
        const child_node = Node{ .ptr = it.? };
        if (child_node.getElementType() != .element) continue;

        if (key) |name| {
            if (std.mem.eql(u8, name, child_node.getName())) {
                return child_node;
            }
        } else {
            return child_node;
        }
    }
    return null;
}

/// Returns the content of a Node (<key>This is the content</key>)
pub fn getContent(node: Node) ?[]const u8 {
    const content = std.mem.span(libxml2.xmlNodeGetContent(node.ptr));

    if (std.mem.eql(u8, content, "\u{0}")) return null;

    return content;
}

/// Returns the name of a Node (</this>)
pub fn getName(node: Node) []const u8 {
    return std.mem.span(node.ptr.name);
}

/// Get the type of an XML element (comment, attribute, etc.).
pub fn getElementType(node: Node) ?ElementType {
    return @enumFromInt(node.ptr.type);
}

// TODO: Create an AttrIterator for .glif
pub const NodeIterator = struct {
    node: ?Node,

    pub fn next(it: *NodeIterator) ?Node {
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

/// Find the first child node and returns a NodeIterator
pub fn iterateArray(array: Node) !NodeIterator {
    const node = array.findChild(null);

    // Don’t unwrap node, empty arrays are OK
    return NodeIterator{
        .node = node,
    };
}

/// Find the first child node which is a key and returns a NodeIterator
pub fn iterateDict(dict: Node) !NodeIterator {
    const node = dict.findChild("key");

    if (node == null) return Error.NoDictKey;

    return NodeIterator{
        .node = node.?,
    };
}

/// Given a XML dict and a struct, maps the dict values into the
/// fields of a struct, following the given key name mapping.
pub fn xmlDictToStruct(
    dict: Node,
    allocator: std.mem.Allocator,
    comptime T: anytype,
) !T {
    var t = T{};
    const key_map = try StructKeyMap(T);

    var node_it = try dict.iterateDict();
    var dict_hm = std.StringHashMap(Node).init(allocator);
    defer dict_hm.deinit();

    while (node_it.next()) |xml_field| {
        const value_node = node_it.next() orelse return Error.NoValue;

        const field_content = xml_field.getContent() orelse {
            return Error.EmptyElement;
        };

        if (key_map.get(field_content)) |key| {
            try dict_hm.putNoClobber(@tagName(key), value_node);
        } else {
            std.debug.print("{s}\n", .{field_content});
            return Error.UnknownKey;
        }
    }

    inline for (std.meta.fields(T)) |field| {
        if (dict_hm.get(field.name)) |value| {
            @field(t, field.name) = try parseForStructField(field, value, allocator);
        }
    }

    logger.debug("Parsed {} successfully", .{T});
    return t;
}

/// An internal function called recursively by xmlDictToStruct to parse
/// a string into the type of a struct field.
pub fn parseForStructField(
    field: std.builtin.Type.StructField,
    node: Node,
    allocator: std.mem.Allocator,
) !field.type {
    @setEvalBranchQuota(1200);
    const node_content = node.getContent().?;

    return switch (field.type) {
        []const u8,
        ?[]const u8,
        => node_content,

        bool,
        ?bool,
        => blk: {
            const node_name = node.getName();

            if (std.mem.eql(u8, node_name, "true")) {
                break :blk true;
            } else if (std.mem.eql(u8, node_name, "false")) {
                break :blk false;
            } else {
                return Error.UnknownValue;
            }
        },

        isize,
        ?isize,
        => try std.fmt.parseInt(isize, node_content, 10),

        usize,
        ?usize,
        => try std.fmt.parseInt(usize, node_content, 10),

        f64,
        ?f64,
        => try std.fmt.parseFloat(f64, node_content),

        ?std.MultiArrayList(FontInfo.GaspRangeRecord) => blk: {
            const soa = try xmlArrayToSoa(node, allocator, FontInfo.GaspRangeRecord);
            break :blk soa;
        },

        FontInfo.GaspBehavior.BitSet => blk: {
            const bit_set = try xmlArrayToIndexedBitSet(node, FontInfo.GaspBehavior);
            break :blk bit_set;
        },

        ?std.ArrayList(FontInfo.NameRecord) => blk: {
            const array = try node.xmlArrayToArray(
                allocator,
                FontInfo.NameRecord,
            );
            break :blk array;
        },

        ?FontInfo.WidthClass => blk: {
            const bit: FontInfo.WidthClass = @enumFromInt(
                try std.fmt.parseInt(u8, node.getContent().?, 10),
            );

            break :blk bit;
        },

        ?FontInfo.StyleMapStyle => blk: {
            const value = try FontInfo.StyleMapStyle.fromString(
                node.getContent().?,
            );
            break :blk value;
        },

        ?std.ArrayList(FontInfo.Guideline) => blk: {
            const array = try node.xmlArrayToArray(
                allocator,
                FontInfo.Guideline,
            );

            break :blk array;
        },

        ?FontInfo.Selection.BitSet => blk: {
            const bit_set = try xmlArrayToIndexedBitSet(node, FontInfo.Selection);
            break :blk bit_set;
        },

        ?FontInfo.Panose => blk: {
            const array = try node.xmlArrayToArray(allocator, u8);
            defer array.deinit();

            std.debug.assert(array.items.len == 10);

            break :blk FontInfo.Panose{
                .family_type = array.items[0],
                .serif_style = array.items[1],
                .weight = array.items[2],
                .proportion = array.items[3],
                .contrast = array.items[4],
                .stroke_variation = array.items[5],
                .arm_style = array.items[6],
                .letterform = array.items[7],
                .midline = array.items[8],
                .x_height = array.items[9],
            };
        },

        ?FontInfo.FamilyClass => blk: {
            const array = try node.xmlArrayToArray(allocator, u8);
            defer array.deinit();

            std.debug.assert(array.items.len == 10);

            break :blk FontInfo.FamilyClass{
                .class = array.items[0],
                .sub_class = array.items[1],
            };
        },

        ?FontInfo.HeadFlags.BitSet => blk: {
            const bit_set = try xmlArrayToIndexedBitSet(node, FontInfo.HeadFlags);
            break :blk bit_set;
        },

        ?std.bit_set.StaticBitSet(128) => blk: {
            const bit_set = try xmlArrayToBitSet(node, std.bit_set.StaticBitSet(128));
            break :blk bit_set;
        },

        ?std.bit_set.StaticBitSet(64) => blk: {
            const bit_set = try xmlArrayToBitSet(node, std.bit_set.StaticBitSet(64));
            break :blk bit_set;
        },

        ?std.bit_set.StaticBitSet(15) => blk: {
            const bit_set = try xmlArrayToBitSet(node, std.bit_set.StaticBitSet(15));
            break :blk bit_set;
        },

        std.ArrayList(isize),
        ?std.ArrayList(isize),
        => blk: {
            const array = try node.xmlArrayToArray(
                allocator,
                isize,
            );
            break :blk array;
        },

        std.ArrayList(f64),
        ?std.ArrayList(f64),
        => blk: {
            const array = try node.xmlArrayToArray(
                allocator,
                f64,
            );
            break :blk array;
        },

        ?FontInfo.PostScriptWindowsCharacterSet => blk: {
            const bit: FontInfo.PostScriptWindowsCharacterSet = @enumFromInt(
                try std.fmt.parseInt(usize, node.getContent().?, 10),
            );

            break :blk bit;
        },

        else => Error.UnknownFieldType,
    };
}

/// Parses an enum specific bitset
pub fn xmlArrayToIndexedBitSet(
    node: Node,
    T: anytype,
) !T.BitSet {
    var bit_set = T.BitSet.initFull();

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        const item_content = item.getContent().?;
        const bit: T = @enumFromInt(try std.fmt.parseInt(u8, item_content, 10));
        bit_set.setPresent(bit, true);
    }

    return bit_set;
}

/// Parses an arrays of unsigned numbers to a bitset
pub fn xmlArrayToBitSet(
    node: Node,
    T: anytype,
) !T {
    var bit_set = T.initEmpty();

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        const item_content = item.getContent().?;
        const bit = try std.fmt.parseInt(u8, item_content, 10);
        bit_set.setValue(bit, true);
    }

    return bit_set;
}

/// Parses an arrays of dicts into a Struct of Arrays
pub fn xmlArrayToSoa(
    node: Node,
    allocator: std.mem.Allocator,
    T: anytype,
) !std.MultiArrayList(T) {
    var soa = std.MultiArrayList(T){};

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        switch (T) {
            FontInfo.GaspRangeRecord => {
                const t_struct = try item.xmlDictToStruct(allocator, T);
                try soa.append(allocator, t_struct);
            },

            else => return Error.UnknownValue,
        }
    }
    return soa;
}

/// Parses an arrays of an arbitrary type into an ArrayList
pub fn xmlArrayToArray(
    node: Node,
    allocator: std.mem.Allocator,
    T: anytype,
) !std.ArrayList(T) {
    var t = std.ArrayList(T).init(allocator);

    var node_it = try node.iterateArray();

    while (node_it.next()) |item| {
        const item_content = item.getContent().?;

        switch (T) {
            []const u8 => {
                try t.append(item_content);
            },

            isize,
            u8,
            => |Type| {
                const t_number = try std.fmt.parseInt(Type, item_content, 10);
                try t.append(t_number);
            },

            f64 => {
                const t_float = try std.fmt.parseFloat(f64, item_content);
                try t.append(t_float);
            },

            FontInfo.Guideline,
            FontInfo.NameRecord,
            FontInfo.Selection,
            => {
                const t_struct = try item.xmlDictToStruct(allocator, T);
                try t.append(t_struct);
            },

            std.ArrayList([]const u8) => {
                var array_node_it = try item.iterateArray();
                while (array_node_it.next()) |array_item| {
                    const array = try array_item.xmlArrayToArray(
                        allocator,
                        []const u8,
                    );
                    try t.append(array);
                }
            },

            else => return Error.UnknownValue,
        }
    }

    logger.debug("Parsed array of {} successfully", .{T});
    return t;
}

const libxml2 = @import("../libxml2.zig");
const std = @import("std");
const logger = @import("../Logger.zig").scopped(.xml_node);
const FontInfo = @import("../FontInfo.zig");
const StructKeyMap = @import("../keys_maps.zig").StructKeyMap;

// Just for tests
const Doc = @import("Doc.zig");

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
    var node = root_node.?.findChild("dict").?;

    var node_it = try node.iterateDict();
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
    node = node.?.findChild("dict");

    _ = try node.?.xmlDictToStruct(
        test_allocator,
        MetaInfo,
    );
}
