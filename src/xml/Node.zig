//! A wrapper around xmlNode
pub const Node = @This();

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
    EmptyElement,
    NoDictKey,
    NoValue,
    UnknownFieldType,
    UnknownValue,
};

pub fn findNextElem(node: Node) ?Node {
    var it = @as(?*libxml2.xmlNode, @ptrCast(node.ptr.next));
    while (it != null) : (it = it.?.next) {
        const next_element = Node{ .ptr = it.? };
        if (next_element.getElementType() == .element) return next_element;
    }

    return null;
}

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

pub fn getContent(node: Node) ?[]const u8 {
    const content = std.mem.span(libxml2.xmlNodeGetContent(node.ptr));

    if (std.mem.eql(u8, content, "\u{0}")) return null;

    return content;
}

pub fn getName(node: Node) []const u8 {
    return std.mem.span(node.ptr.name);
}

/// Get the type of an XML element (comment, attribute, etc.).
pub fn getElementType(node: Node) ?ElementType {
    return @enumFromInt(node.ptr.type);
}

/// Get the type of a node based on its name.
/// For example: <array/> returns .array
pub fn getNodeType(node: Node) ?PlistType {
    return std.meta.stringToEnum(PlistType, node.getName());
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

/// Represents every types of Plist node.
pub const PlistType = enum {
    dict,
    key,
    integer,
    real,
    string,
    array,
    true,
    false,
};

/// Represents any UFO value, potentially containing other UFO values.
pub const Value = union(enum) {
    bool: bool,
    true: bool,
    false: bool,
    number_string: []const u8,
    string: []const u8,

    style_map_style_name: FontInfo.StyleMapStyle,

    opentype_gasp_range_records: std.MultiArrayList(FontInfo.GaspRangeRecord),
    range_gasp_behavior: FontInfo.GaspBehavior.BitSet,
    opentype_name_records: std.ArrayList(FontInfo.NameRecord),
    name_record: FontInfo.NameRecord,

    woff_metadata_unique_id: FontInfo.WoffMetadataUniqueID,
    woff_metadata_vendor: FontInfo.WoffMetadataVendor,
    woff_metadata_credits: FontInfo.WoffMetadataCredit,
    woff_metadata_description: FontInfo.WoffMetadataDescription,
    woff_metadata_license: FontInfo.WoffMetadataLicense,
    woff_metadata_copyright: FontInfo.WoffMetadataCopyright,
    woff_metadata_trademark: FontInfo.WoffMetadataTrademark,
    woff_metadata_licensee: FontInfo.WoffMetadataLicensee,
    woff_metadata_extensions: std.MultiArrayList(FontInfo.WoffMetadataExtension),

    guidelines: std.ArrayList(FontInfo.Guideline),

    opentype_head_flags: FontInfo.HeadFlags.BitSet,

    opentype_os2_width_class: FontInfo.WidthClass,
    opentype_os2_selection: FontInfo.Selection.BitSet,
    opentype_os2_unicode_ranges: std.StaticBitSet(128),
    opentype_os2_codepage_ranges: std.StaticBitSet(64),
    opentype_os2_type: std.StaticBitSet(15),
    opentype_os2_family_class: FontInfo.FamilyClass,
    opentype_os2_panose: FontInfo.Panose,

    postscript_blue_values: std.ArrayList(isize),
    postscript_other_blues: std.ArrayList(isize),
    postscript_family_blues: std.ArrayList(isize),
    postscript_family_other_blues: std.ArrayList(isize),
    postscript_stem_snap_h: std.ArrayList(f64),
    postscript_stem_snap_v: std.ArrayList(f64),
    postscript_windows_character_set: FontInfo.PostScriptWindowsCharacterSet,
};

pub fn xmlValueParse(
    node: Node,
    allocator: std.mem.Allocator,
    key: []const u8,
) anyerror!Value {
    var value_type = std.meta.stringToEnum(
        @typeInfo(Value).Union.tag_type.?,
        key,
    );
    if (value_type == null) {
        const tag_from_node_name = std.meta.stringToEnum(
            @typeInfo(Value).Union.tag_type.?,
            node.getName(),
        );

        value_type = blk: {
            if (tag_from_node_name) |tag| {
                break :blk tag;
            } else {
                const node_type = node.getNodeType();
                if (node_type == .integer or node_type == .real) {
                    break :blk Value.number_string;
                }

                break :blk null;
            }
        };
    }

    switch (value_type.?) {
        .bool,
        .false,
        .true,
        => {
            const node_type = node.getNodeType();

            if (node_type == .true) {
                return Value{ .bool = true };
            } else if (node_type == .false) {
                return Value{ .bool = false };
            } else {
                return Error.UnknownValue;
            }
        },

        .number_string => return Value{ .number_string = node.getContent().? },
        .string => return Value{ .string = node.getContent().? },

        .style_map_style_name => {
            const value = try FontInfo.StyleMapStyle.fromString(
                node.getContent().?,
            );
            return Value{ .style_map_style_name = value };
        },

        .opentype_gasp_range_records => {
            const soa = try xmlArrayToSoa(node, allocator, FontInfo.GaspRangeRecord);
            return Value{ .opentype_gasp_range_records = soa };
        },

        .range_gasp_behavior => {
            const bit_set = try xmlArrayToIndexedBitSet(node, FontInfo.GaspBehavior);
            return Value{ .range_gasp_behavior = bit_set };
        },

        .opentype_head_flags => {
            const bit_set = try xmlArrayToIndexedBitSet(node, FontInfo.HeadFlags);
            return Value{ .opentype_head_flags = bit_set };
        },

        .opentype_name_records => {
            const array = try node.xmlArrayToArray(
                allocator,
                FontInfo.NameRecord,
                null,
            );
            return Value{ .opentype_name_records = array };
        },

        .opentype_os2_selection => {
            const bit_set = try xmlArrayToIndexedBitSet(node, FontInfo.Selection);
            return Value{ .opentype_os2_selection = bit_set };
        },

        .opentype_os2_unicode_ranges => {
            const bit_set = try xmlArrayToBitSet(node, std.bit_set.StaticBitSet(128));
            return Value{ .opentype_os2_unicode_ranges = bit_set };
        },

        .opentype_os2_codepage_ranges => {
            const bit_set = try xmlArrayToBitSet(node, std.bit_set.StaticBitSet(64));
            return Value{ .opentype_os2_codepage_ranges = bit_set };
        },

        .opentype_os2_type => {
            const bit_set = try xmlArrayToBitSet(node, std.bit_set.StaticBitSet(15));
            return Value{ .opentype_os2_type = bit_set };
        },

        .opentype_os2_family_class => {
            const array = try node.xmlArrayToArray(allocator, u8, 10);
            defer array.deinit();
            return Value{
                .opentype_os2_family_class = FontInfo.FamilyClass{
                    .class = array.items[0],
                    .sub_class = array.items[1],
                },
            };
        },

        .opentype_os2_panose => {
            const array = try node.xmlArrayToArray(allocator, u8, 10);
            defer array.deinit();
            return Value{
                .opentype_os2_panose = FontInfo.Panose{
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
                },
            };
        },

        .opentype_os2_width_class => {
            const bit: FontInfo.WidthClass = @enumFromInt(
                try std.fmt.parseInt(u8, node.getContent().?, 10),
            );

            return Value{ .opentype_os2_width_class = bit };
        },

        .postscript_blue_values => {
            const array = try node.xmlArrayToArray(
                allocator,
                isize,
                14,
            );

            return Value{ .postscript_blue_values = array };
        },

        .postscript_family_blues => {
            const array = try node.xmlArrayToArray(
                allocator,
                isize,
                14,
            );

            return Value{
                .postscript_family_blues = array,
            };
        },

        .postscript_other_blues => {
            const array = try node.xmlArrayToArray(
                allocator,
                isize,
                10,
            );

            return Value{
                .postscript_other_blues = array,
            };
        },

        .postscript_family_other_blues => {
            const array = try node.xmlArrayToArray(
                allocator,
                isize,
                10,
            );

            return Value{
                .postscript_family_other_blues = array,
            };
        },

        .postscript_stem_snap_h => {
            const array = try node.xmlArrayToArray(
                allocator,
                f64,
                null,
            );

            return Value{
                .postscript_stem_snap_h = array,
            };
        },

        .postscript_stem_snap_v => {
            const array = try node.xmlArrayToArray(
                allocator,
                f64,
                null,
            );

            return Value{
                .postscript_stem_snap_v = array,
            };
        },

        .postscript_windows_character_set => {
            const bit: FontInfo.PostScriptWindowsCharacterSet = @enumFromInt(
                try std.fmt.parseInt(usize, node.getContent().?, 10),
            );

            return Value{
                .postscript_windows_character_set = bit,
            };
        },

        .guidelines => {
            const array = try node.xmlArrayToArray(
                allocator,
                FontInfo.Guideline,
                null,
            );

            return Value{
                .guidelines = array,
            };
        },

        else => {
            return Error.UnknownValue;
        },
    }
}

pub fn xmlArrayToIndexedBitSet(
    node: Node,
    T: anytype,
) !T.BitSet {
    var bit_set = T.BitSet{};

    var node_it = try node.iterateArray();
    while (node_it.next()) |item| {
        const item_content = item.getContent().?;
        const bit: T = @enumFromInt(try std.fmt.parseInt(u8, item_content, 10));
        bit_set.toggle(bit);
    }

    return bit_set;
}

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

pub fn xmlArrayToArray(
    node: Node,
    allocator: std.mem.Allocator,
    T: anytype,
    capacity: ?usize,
) !std.ArrayList(T) {
    var t: std.ArrayList(T) = undefined;
    if (capacity) |c| {
        t = try std.ArrayList(T).initCapacity(allocator, c);
    } else {
        t = std.ArrayList(T).init(allocator);
    }

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
                        null,
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

// This is medieval
/// Given a XML dict and a struct, maps the dict values into the
/// fields of a struct, following the given key name mapping.
pub fn xmlDictToStruct(
    dict: Node,
    allocator: std.mem.Allocator,
    comptime T: anytype,
) !T {
    var t = T{};
    const key_map = StructKeyMap(T);

    var node_it = try dict.iterateDict();
    var dict_hm = std.StringHashMap(Value).init(allocator);
    defer dict_hm.deinit();

    while (node_it.next()) |xml_field| {
        const value_node = node_it.next() orelse return Error.NoValue;

        const field_content = xml_field.getContent() orelse {
            return Error.EmptyElement;
        };

        var key: []const u8 = xml_field.getName();
        if (key_map) |map| {
            if (map.get(field_content)) |k|
                key = k;
        }

        const value = try value_node.xmlValueParse(
            allocator,
            key,
        );

        try dict_hm.put(key, value);
    }

    inline for (std.meta.fields(T)) |field| {
        if (dict_hm.get(field.name)) |value| {
            @field(t, field.name) = try parseForStructField(field, value);
        }
    }

    logger.debug("Parsed {} successfully", .{T});
    return t;
}

/// An internal function called recursively by dictToStruct to parse a
/// string into the type of a struct field.
pub fn parseForStructField(
    field: std.builtin.Type.StructField,
    value: Value,
) !field.type {
    @setEvalBranchQuota(1200);
    return switch (field.type) {
        []const u8,
        ?[]const u8,
        => value.string,

        bool,
        ?bool,
        => value.bool,

        isize,
        ?isize,
        => try std.fmt.parseInt(isize, value.number_string, 10),

        usize,
        ?usize,
        => try std.fmt.parseInt(usize, value.number_string, 10),

        f64,
        ?f64,
        => try std.fmt.parseFloat(f64, value.number_string),

        ?std.MultiArrayList(FontInfo.GaspRangeRecord) => value.opentype_gasp_range_records,
        FontInfo.GaspBehavior.BitSet => value.range_gasp_behavior,

        ?std.ArrayList(FontInfo.NameRecord) => value.opentype_name_records,

        ?FontInfo.WidthClass => value.opentype_os2_width_class,

        ?FontInfo.StyleMapStyle => value.style_map_style_name,

        ?std.ArrayList(FontInfo.Guideline) => value.guidelines,

        ?FontInfo.Selection.BitSet => value.opentype_os2_selection,

        ?FontInfo.Panose => value.opentype_os2_panose,

        ?FontInfo.FamilyClass => value.opentype_os2_family_class,

        ?FontInfo.HeadFlags.BitSet => value.opentype_head_flags,

        ?std.bit_set.StaticBitSet(128) => value.opentype_os2_unicode_ranges,
        ?std.bit_set.StaticBitSet(64) => value.opentype_os2_codepage_ranges,
        ?std.bit_set.StaticBitSet(15) => value.opentype_os2_type,

        std.ArrayList(isize),
        ?std.ArrayList(isize),
        => blk: {
            if (std.mem.eql(
                u8,
                field.name,
                "postscript_blue_values",
            ))
                break :blk value.postscript_blue_values;

            if (std.mem.eql(
                u8,
                field.name,
                "postscript_other_blues",
            ))
                break :blk value.postscript_other_blues;

            if (std.mem.eql(
                u8,
                field.name,
                "postscript_family_blues",
            ))
                break :blk value.postscript_family_blues;

            if (std.mem.eql(
                u8,
                field.name,
                "postscript_family_other_blues",
            ))
                break :blk value.postscript_family_other_blues;

            break :blk null;
        },

        std.ArrayList(f64),
        ?std.ArrayList(f64),
        => blk: {
            if (std.mem.eql(
                u8,
                field.name,
                "postscript_stem_snap_h",
            ))
                break :blk value.postscript_stem_snap_h;

            if (std.mem.eql(
                u8,
                field.name,
                "postscript_stem_snap_v",
            ))
                break :blk value.postscript_stem_snap_v;

            break :blk null;
        },

        ?FontInfo.PostScriptWindowsCharacterSet => value.postscript_windows_character_set,

        else => Error.UnknownFieldType,
    };
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
