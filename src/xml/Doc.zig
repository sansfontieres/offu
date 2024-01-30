pub const Doc = @This();

const std = @import("std");
const libxml2 = @import("../libxml2.zig");
const logger = @import("../Logger.zig").scopped(.xml);
pub const FontInfo = @import("../FontInfo.zig");
const StructKeyMap = @import("../keys_maps.zig").StructKeyMap;

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
        NotAnArray,
        NotAStruct,
        NoValue,
        NoContent,
        NoDictKey,
        UnknownKey,
        UnknownValue,
        UnknownFieldType,
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

        if (node == null) return Node.Error.NoDictKey;

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
        number_string: []const u8,
        string: []const u8,

        style_map_style: FontInfo.StyleMapStyle,

        gasp_range_record: FontInfo.GaspRangeRecord,
        name_record: FontInfo.NameRecord,
        family_class: FontInfo.FamilyClass,
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

        opentype_os2_width_class: FontInfo.WidthClass,
        opentype_os2_selection: std.ArrayList(FontInfo.Selection),
        opentype_os2_unicode_ranges: std.ArrayList(u8),
        opentype_os2_codepage_ranges: std.ArrayList(u8),
        opentype_os2_type: std.ArrayList(u8),

        postscript_blue_values: std.ArrayList(isize),
        postscript_other_blues: std.ArrayList(isize),
        postscript_family_blues: std.ArrayList(isize),
        postscript_family_other_blues: std.ArrayList(isize),
        postscript_stem_snap_h: std.ArrayList(FontInfo.IntOrFloat),
        postscript_stem_snap_v: std.ArrayList(FontInfo.IntOrFloat),
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
                    if (node_type == .integer or node_type == .real)
                        break :blk Value.number_string;

                    break :blk null;
                }
            };
        }

        switch (value_type.?) {
            .bool => {
                const node_type = node.getNodeType();

                if (node_type == .true) {
                    return Value{ .bool = true };
                } else if (node_type == .false) {
                    return Value{ .bool = false };
                } else {
                    return Node.Error.UnknownValue;
                }
            },

            .string => return Value{ .string = node.getContent().? },
            .number_string => return Value{ .number_string = node.getContent().? },

            .style_map_style => {
                const value = try FontInfo.StyleMapStyle.fromString(
                    node.getContent().?,
                );
                return Value{ .style_map_style = value };
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
                    FontInfo.IntOrFloat,
                    null,
                );

                return Value{
                    .postscript_stem_snap_h = array,
                };
            },

            .postscript_stem_snap_v => {
                const array = try node.xmlArrayToArray(
                    allocator,
                    FontInfo.IntOrFloat,
                    null,
                );

                return Value{
                    .postscript_stem_snap_v = array,
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

            else => return Node.Error.UnknownValue,
        }
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

        while (node_it.next()) |xml_field| {
            const field_content = xml_field.getContent().?;

            switch (T) {
                FontInfo.Guideline,
                FontInfo.Selection,
                => {
                    const t_struct = try xml_field.xmlDictToStruct(allocator, T);
                    try t.append(t_struct);
                },

                isize,
                u8,
                => |Type| {
                    const t_number = try std.fmt.parseInt(Type, field_content, 10);
                    try t.append(t_number);
                },

                f64 => {
                    const t_float = try std.fmt.parseFloat(f64, field_content);
                    try t.append(t_float);
                },

                else => return Node.Error.UnknownValue,
            }
        }

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
            const value_node = node_it.next() orelse return Node.Error.NoValue;

            const field_content = xml_field.getContent() orelse {
                return Doc.Error.EmptyElement;
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
            ?f64, // Covers FontInfo.IntOrFloat
            => try std.fmt.parseFloat(f64, value.number_string),

            FontInfo.StyleMapStyle,
            ?FontInfo.StyleMapStyle,
            => value.style_map_style,

            std.ArrayList(FontInfo.Guideline),
            ?std.ArrayList(FontInfo.Guideline),
            => value.guidelines,

            std.ArrayList(FontInfo.Selection),
            ?std.ArrayList(FontInfo.Selection),
            => value.opentype_os2_selection,

            std.ArrayList(u8),
            ?std.ArrayList(u8),
            => blk: {
                if (std.mem.eql(
                    u8,
                    field.name,
                    "opentype_os2_unicode_ranges",
                ))
                    break :blk value.opentype_os2_unicode_ranges;

                if (std.mem.eql(
                    u8,
                    field.name,
                    "opentype_os2_codepage_ranges",
                ))
                    break :blk value.opentype_os2_codepage_ranges;

                if (std.mem.eql(
                    u8,
                    field.name,
                    "opentype_os2_type",
                ))
                    break :blk value.opentype_os2_type;

                break :blk null;
            },

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

            FontInfo.PostScriptWindowsCharacterSet,
            ?FontInfo.PostScriptWindowsCharacterSet,
            => value.postscript_windows_character_set,

            else => Node.Error.UnknownFieldType,
        };
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
