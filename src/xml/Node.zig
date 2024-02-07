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
    MalformedFile,
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
            if (mem.eql(u8, name, child_node.getName())) return child_node;
        } else return child_node;
    }
    return null;
}

/// Returns the content of a Node (<key>This is the content</key>)
pub fn getContent(node: Node) ?[]const u8 {
    const content = mem.span(libxml2.xmlNodeGetContent(node.ptr));

    if (mem.eql(u8, content, "\u{0}")) return null;

    return content;
}

/// Returns the name of a Node (</this>)
pub fn getName(node: Node) []const u8 {
    return mem.span(node.ptr.name);
}

/// Get the type of an XML element (comment, attribute, etc.).
pub fn getElementType(node: Node) ?ElementType {
    return std.meta.intToEnum(ElementType, node.ptr.type) catch return null;
}

// TODO: Create an AttrIterator for .glif
pub const NodeIterator = struct {
    node: ?Node,

    pub fn next(it: *NodeIterator) ?Node {
        while (it.node) |node| {
            if (node.getElementType() != .element) continue;

            var next_node: ?Node = null;
            next_node = node.findNextElem();
            it.node = next_node;

            return node;
        }
        return null;
    }
};

/// Find the first child node and returns a NodeIterator
pub fn iterateArray(array: Node) !NodeIterator {
    const node = array.findChild(null);

    // Don’t unwrap node, empty arrays are OK
    return NodeIterator{ .node = node };
}

/// Find the first child node which is a key and returns a NodeIterator
pub fn iterateDict(dict: Node) !NodeIterator {
    const node = dict.findChild("key");

    if (node == null) return Error.NoDictKey;

    return NodeIterator{ .node = node.? };
}

/// Given a XML dict and a struct, maps the dict values into the
/// fields of a struct, following the given key name mapping.
pub fn dictToStruct(dict: Node, allocator: Allocator, comptime T: anytype) !T {
    var t = T{};
    const key_map = try ComptimeKeyMaps.get(T);

    var node_it = try dict.iterateDict();
    var dict_hm = std.StringHashMap(Node).init(allocator);
    defer dict_hm.deinit();

    while (node_it.next()) |xml_field| {
        const value_node = node_it.next() orelse return Error.NoValue;

        const field_content = xml_field.getContent() orelse return Error.EmptyElement;

        if (key_map.get(field_content)) |key| {
            try dict_hm.putNoClobber(@tagName(key), value_node);
        } else {
            logger.err("Unknown key: {s}", .{field_content});
            logger.err("→ {s}:{d}", .{ xml_field.ptr.doc.*.URL, xml_field.ptr.line });
            return Error.UnknownKey;
        }
    }

    inline for (std.meta.fields(T)) |field| {
        if (dict_hm.get(field.name)) |value| {
            @field(t, field.name) = try value.parse(field, allocator);
        }
    }

    logger.debug("{} was successfully parsed", .{T});
    return t;
}

/// An internal function called recursively by dictToStruct to parse a
/// Node into the type of a struct field.
pub fn parse(node: Node, field: StructField, allocator: Allocator) !field.type {
    const node_content = node.getContent().?;

    return switch (field.type) {
        []const u8, ?[]const u8 => node_content,

        bool, ?bool => blk: {
            const node_name = node.getName();

            if (mem.eql(u8, node_name, "true")) {
                break :blk true;
            } else if (mem.eql(u8, node_name, "false")) {
                break :blk false;
            } else {
                logger.err("Unknown value: {s}", .{node_name});
                logger.err("→ {s}:{d}", .{ node.ptr.doc.*.URL, node.ptr.line });
                return Error.UnknownValue;
            }
        },

        isize, ?isize => try fmt.parseInt(isize, node_content, 10),
        usize, ?usize => try fmt.parseInt(usize, node_content, 10),
        f64, ?f64 => try fmt.parseFloat(f64, node_content),

        ?std.MultiArrayList(FontInfo.GaspRangeRecord) => try node.arrayToSoa(
            allocator,
            FontInfo.GaspRangeRecord,
        ),

        FontInfo.GaspBehavior.BitSet => try node.arrayToEnumSet(FontInfo.GaspBehavior),

        ?std.ArrayList(FontInfo.NameRecord) => try node.arrayToArrayList(
            allocator,
            FontInfo.NameRecord,
        ),

        ?FontInfo.WidthClass => try FontInfo.WidthClass.fromString(node_content),
        ?FontInfo.StyleMapStyle => try FontInfo.StyleMapStyle.fromString(node_content),

        ?std.ArrayList(FontInfo.Guideline) => try node.arrayToArrayList(
            allocator,
            FontInfo.Guideline,
        ),

        ?FontInfo.Selection.BitSet => try node.arrayToEnumSet(FontInfo.Selection),

        ?FontInfo.Panose => blk: {
            const array = try node.arrayToArrayList(allocator, u8);
            defer array.deinit();

            const items = array.items;
            const array_len = items.len;
            if (array_len != 10) {
                logger.err("Panose should be 10 elements long: {d}", .{array_len});
                logger.err("→ {s}:{d}", .{ node.ptr.doc.*.URL, node.ptr.line });
                return Error.MalformedFile;
            }

            break :blk FontInfo.Panose{
                .family_type = items[0],
                .serif_style = items[1],
                .weight = items[2],
                .proportion = items[3],
                .contrast = items[4],
                .stroke_variation = items[5],
                .arm_style = items[6],
                .letterform = items[7],
                .midline = items[8],
                .x_height = items[9],
            };
        },

        ?FontInfo.FamilyClass => blk: {
            const array = try node.arrayToArrayList(allocator, u8);
            defer array.deinit();

            const items = array.items;
            const array_len = items.len;
            if (array_len != 2) {
                logger.err("FamilyClass should be 2 elements long: {d}", .{array_len});
                logger.err("→ {s}:{d}", .{ node.ptr.doc.*.URL, node.ptr.line });
                return Error.MalformedFile;
            }

            break :blk FontInfo.FamilyClass{ .class = items[0], .sub_class = items[1] };
        },

        ?FontInfo.HeadFlags.BitSet => try node.arrayToEnumSet(FontInfo.HeadFlags),

        ?std.StaticBitSet(128) => try node.arrayToBitSet(128),
        ?std.StaticBitSet(64) => try node.arrayToBitSet(64),
        ?std.StaticBitSet(15) => try node.arrayToBitSet(15),

        ?std.ArrayList(isize) => try node.arrayToArrayList(allocator, isize),
        ?std.ArrayList(f64) => try node.arrayToArrayList(allocator, f64),

        ?FontInfo.WindowsCharacterSet => try FontInfo.WindowsCharacterSet.fromString(node_content),

        else => Error.UnknownFieldType,
    };
}

/// Parses an enum specific bitset
pub fn arrayToEnumSet(node: Node, T: anytype) !T.BitSet {
    var bit_set = T.BitSet.initFull();

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        const item_content = item.getContent().?;
        const i = try fmt.parseInt(u8, item_content, 10);
        const bit = try std.meta.intToEnum(T, i);
        bit_set.setPresent(bit, true);
    }

    return bit_set;
}

/// Parses an arrays of unsigned numbers to a bitset
pub fn arrayToBitSet(node: Node, comptime size: usize) !std.StaticBitSet(size) {
    var bit_set = std.StaticBitSet(size).initEmpty();

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        const item_content = item.getContent().?;
        const bit = try fmt.parseInt(u8, item_content, 10);
        bit_set.setValue(bit, true);
    }

    return bit_set;
}

/// Parses an arrays of dicts into a Struct of Arrays
pub fn arrayToSoa(node: Node, allocator: Allocator, T: anytype) !std.MultiArrayList(T) {
    var soa = std.MultiArrayList(T){};

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        switch (T) {
            FontInfo.GaspRangeRecord => {
                const s = try item.dictToStruct(allocator, T);
                try soa.append(allocator, s);
            },

            else => return Error.UnknownValue,
        }
    }
    return soa;
}

/// Parses an arrays of an arbitrary type into an ArrayList
pub fn arrayToArrayList(node: Node, allocator: Allocator, T: anytype) !std.ArrayList(T) {
    var t = std.ArrayList(T).init(allocator);

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        const item_content = item.getContent().?;

        switch (T) {
            []const u8 => try t.append(item_content),

            isize, u8 => |I| try t.append(try fmt.parseInt(I, item_content, 10)),

            f64 => try t.append(try fmt.parseFloat(f64, item_content)),

            FontInfo.Guideline,
            FontInfo.NameRecord,
            FontInfo.Selection,
            => try t.append(try item.dictToStruct(allocator, T)),

            std.ArrayList([]const u8) => {
                var array_node_it = try item.iterateArray();
                while (array_node_it.next()) |array_item| {
                    const array = try array_item.arrayToArrayList(allocator, []const u8);
                    try t.append(array);
                }
            },

            else => return Error.UnknownValue,
        }
    }

    logger.debug("Array of {} was successfully parsed", .{T});
    return t;
}

const libxml2 = @import("../libxml2.zig");
const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const Allocator = mem.Allocator;
const StructField = std.builtin.Type.StructField;

const logger = @import("../Logger.zig").scopped(.xml_node);
const FontInfo = @import("../FontInfo.zig");
const ComptimeKeyMaps = @import("../ComptimeKeyMaps.zig");

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

    _ = try node.?.dictToStruct(test_allocator, MetaInfo);
}
