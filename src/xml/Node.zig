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

pub fn getProp(node: Node, key: []const u8) ?[]const u8 {
    const raw_prop = libxml2.xmlGetProp(node.ptr, key.ptr);

    if (raw_prop == 0) return null;

    return mem.span(raw_prop);
}

/// Get the type of an XML element (comment, attribute, etc.).
pub fn getElementType(node: Node) ?ElementType {
    return std.meta.intToEnum(ElementType, node.ptr.type) catch return null;
}

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

pub fn iterate(node: Node) NodeIterator {
    return NodeIterator{ .node = node };
}

// TODO: This sucks.
/// Given a root node, try to parse each node of a *.glif file and their
/// attributes to a struct.
pub fn glifToStruct(node: Node, allocator: Allocator) !Glif {
    var glif = Glif{};
    const key_map = try ComptimeKeyMaps.get(Glif);

    glif.codepoints = std.AutoHashMap(u21, void).init(allocator);
    glif.anchors = std.ArrayList(Glif.Anchor).init(allocator);

    var outline_node: ?Node = null;

    var node_it = node.iterate();
    while (node_it.next()) |cur| {
        const node_name = cur.getName();
        const key: std.meta.FieldEnum(Glif) = key_map.get(node_name) orelse {
            logger.warn("Unknown Node: {s}", .{node_name});
            continue;
        };

        switch (key) {
            .format_version => {
                glif.format_version.major = try fmt.parseInt(usize, cur.getProp("format").?, 10);

                if (cur.getProp("formatMinor")) |format_minor| {
                    glif.format_version.minor = try std.fmt.parseInt(usize, format_minor, 10);
                }

                if (cur.findChild(null)) |child_element| node_it = child_element.iterate();
            },

            .advance => {
                if (cur.getProp("height")) |h| {
                    glif.advance.height = try std.fmt.parseFloat(f64, h);
                }

                if (cur.getProp("width")) |w| {
                    glif.advance.width = try std.fmt.parseFloat(f64, w);
                }
            },

            .codepoints => {
                const codepoint = try Glif.codepointFromString(cur.getProp("hex").?);
                try glif.codepoints.put(codepoint, {});
            },

            .outline => {
                glif.outline = Glif.Outline{};
                outline_node = cur.findChild(null);
            },

            .anchors => {
                const x = try std.fmt.parseFloat(f64, cur.getProp("x").?);
                const y = try std.fmt.parseFloat(f64, cur.getProp("y").?);
                var name: ?[]const u8 = null;
                var identifier: ?[]const u8 = null;
                if (cur.getProp("name")) |prop_name| name = prop_name;
                if (cur.getProp("identifier")) |prop_identifier| identifier = prop_identifier;

                try glif.anchors.append(.{
                    .x = x,
                    .y = y,
                    .name = name,
                    .identifier = identifier,
                });
            },

            else => return Error.UnknownKey,
        }
    }

    if (outline_node) |o_node| node_it = o_node.iterate();
    var component_inited = false;
    var contour_inited = false;
    while (node_it.next()) |cur| {
        if (std.mem.eql(u8, cur.getName(), "component")) {
            if (!component_inited) {
                glif.outline.?.components = std.ArrayList(Glif.Component).init(allocator);
                component_inited = true;
            }

            const base = cur.getProp("base").?;

            var x_scale: f64 = 1;
            var xy_scale: f64 = 0;
            var yx_scale: f64 = 0;
            var y_scale: f64 = 1;
            var x_offset: f64 = 0;
            var y_offset: f64 = 0;

            if (cur.getProp("xScale")) |str| x_scale = try fmt.parseFloat(f64, str);
            if (cur.getProp("xyScale")) |str| xy_scale = try fmt.parseFloat(f64, str);
            if (cur.getProp("yxScale")) |str| yx_scale = try fmt.parseFloat(f64, str);
            if (cur.getProp("yScale")) |str| y_scale = try fmt.parseFloat(f64, str);
            if (cur.getProp("xOffset")) |str| x_offset = try fmt.parseFloat(f64, str);
            if (cur.getProp("yOffset")) |str| y_offset = try fmt.parseFloat(f64, str);

            var color: ?Color = null;
            if (cur.getProp("color")) |str| color = try Color.fromString(str);
            const identifier: ?[]const u8 = cur.getProp("identifier");

            try glif.outline.?.components.?.append(.{
                .base = base,
                .x_scale = x_scale,
                .xy_scale = xy_scale,
                .yx_scale = yx_scale,
                .y_scale = y_scale,
                .x_offset = x_offset,
                .y_offset = y_offset,
                .color = color,
                .identifier = identifier,
            });
        }

        if (std.mem.eql(u8, cur.getName(), "contour")) {
            if (!contour_inited) {
                glif.outline.?.contours = std.ArrayList(Glif.Contour).init(allocator);
                contour_inited = true;
            }

            const identifier: ?[]const u8 = cur.getProp("identifier");
            const points = try cur.arrayToArrayList(allocator, Glif.Point);

            try glif.outline.?.contours.?.append(.{ .identifier = identifier, .points = points });
        }
    }

    return glif;
}

/// Given a XML dict and a struct, maps the dict values into the
/// fields of a struct, following the given key name mapping.
pub fn dictToStruct(dict: Node, allocator: Allocator, comptime T: anytype) !T {
    var t = T{};
    const key_map = try ComptimeKeyMaps.get(T);

    var dict_hm = std.StringHashMap(Node).init(allocator);
    defer dict_hm.deinit();

    var node_it = try dict.iterateDict();
    while (node_it.next()) |xml_field| {
        const value_node = node_it.next() orelse return Error.NoValue;

        const field_content = xml_field.getContent() orelse return Error.EmptyElement;

        if (key_map.get(field_content)) |key| {
            try dict_hm.putNoClobber(@tagName(key), value_node);
        } else {
            const path = try Doc.fromNode(xml_field).getPath(allocator);
            logger.err("Unknown key: {s}", .{field_content});
            logger.err("→ {s}:{d}", .{ path, xml_field.ptr.line });
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
                const path = try Doc.fromNode(node).getPath(allocator);
                logger.err("Unknown value: {s}", .{node_name});
                logger.err("→ {s}:{d}", .{ path, node.ptr.line });
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
                const path = try Doc.fromNode(node).getPath(allocator);
                logger.err("Panose should be 10 elements long: {d}", .{array_len});
                logger.err("→ {s}:{d}", .{ path, node.ptr.line });
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
                const path = try Doc.fromNode(node).getPath(allocator);
                logger.err("FamilyClass should be 2 elements long: {d}", .{array_len});
                logger.err("→ {s}:{d}", .{ path, node.ptr.line });
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
    const doc = Doc.fromNode(node);

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        switch (T) {
            FontInfo.GaspRangeRecord => {
                const s = try item.dictToStruct(allocator, T);
                try soa.append(allocator, s);
            },

            Layer => {
                const layers_arry = try node.arrayToArrayList(allocator, std.ArrayList([]const u8));
                defer layers_arry.deinit();

                for (layers_arry.items) |l| {
                    defer l.deinit();

                    const items = l.items;
                    if (items.len != 2) {
                        logger.err("Layer is not two elements long: {d}", .{items.len});
                        return Error.MalformedFile;
                    }

                    const doc_path = try doc.getPath(allocator);
                    defer allocator.free(doc_path);

                    const root = std.fs.path.dirname(doc_path).?;

                    const layer = try Layer.init(allocator, .{
                        .name = items[0],
                        .root = root,
                        .dirname = items[1],
                    });

                    try soa.append(allocator, layer);
                }
            },

            else => return Error.UnknownValue,
        }
    }

    return soa;
}

// TODO: const Child = std.meta.Child(T);
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

            Glif.Point => {
                const x = try fmt.parseFloat(f64, item.getProp("x").?);
                const y = try fmt.parseFloat(f64, item.getProp("y").?);
                var point_type: Glif.PointType = undefined;
                var smooth = false;
                var name: ?[]const u8 = null;
                var identifier: ?[]const u8 = null;

                if (item.getProp("type")) |str| {
                    point_type = std.meta.stringToEnum(Glif.PointType, str) orelse
                        return Error.UnknownValue;
                }

                if (item.getProp("smooth")) |str| {
                    if (mem.eql(u8, str, "yes")) smooth = true;
                    if (mem.eql(u8, str, "no")) smooth = false;
                }

                if (item.getProp("name")) |str| name = str;
                if (item.getProp("identifier")) |str| identifier = str;

                try t.append(.{
                    .x = x,
                    .y = y,
                    .type = point_type,
                    .smooth = smooth,
                    .name = name,
                    .identifier = identifier,
                });
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

const logger = @import("../Logger.zig").scopped(.@"xml Node");

const FontInfo = @import("../FontInfo.zig");
const Layer = @import("../Layer.zig");
const Glif = @import("../Glif.zig");
const ComptimeKeyMaps = @import("../ComptimeKeyMaps.zig");
const Color = @import("../Color.zig");

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
