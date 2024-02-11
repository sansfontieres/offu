//! Representation of a Glyph per [contents.glif] and a given [*.glif].
//!
//! [*.glif]: https://unifiedfontobject.org/versions/ufo3/glyphs/glif/
pub const Glif = @This();

/// The name of the glyph.
/// It is extracted from contents.plist rather than from the .glif
/// itself.
name: []const u8 = undefined,

path: []const u8 = undefined,

format_version: FormatVersion = undefined,

advance: Advance = undefined,

/// The string is case-insensitive and must contain the hex value
/// without a prefix.
/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#unicode
codepoints: std.AutoHashMap(u21, void) = undefined,

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#image
image: ?Image = null,

guidelines: std.ArrayList(Guideline) = undefined,
anchors: std.ArrayList(Anchor) = undefined,
outline: ?Outline = null,

// TODO: parse lib
// lib:,

pub const FormatVersion = struct {
    major: usize = undefined,

    /// Optional if 0
    minor: ?usize = null,
};

/// .width and .height are optional if set to 0
/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#advance
pub const Advance = struct {
    width: f64 = 0,
    height: f64 = 0,
};

pub const Image = struct {
    // The image file name, including any file extension, not an
    // absolute or relative path in the file system.
    filename: []const u8 = undefined,

    x_scale: f64 = 1,
    xy_scale: f64 = 0,
    yx_scale: f64 = 0,
    y_scale: f64 = 1,

    x_offset: f64 = 0,
    y_offset: f64 = 0,

    color: ?Color = null,
};

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#guideline
pub const Guideline = struct {
    x: f64 = 0,
    y: f64 = 0,
    angle: f64 = 0,

    name: ?[]const u8 = null,

    color: ?Color = null,

    // TODO: should be unique and follow this convention:
    // https://unifiedfontobject.org/versions/ufo3/conventions/#identifiers
    identifier: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#anchor
pub const Anchor = struct {
    x: f64 = undefined,
    y: f64 = undefined,

    // https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#anchor-naming-conventions
    name: ?[]const u8 = null,

    // TODO: should be unique and follow this convention:
    // https://unifiedfontobject.org/versions/ufo3/conventions/#identifiers
    identifier: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#outline
pub const Outline = struct {
    components: ?std.ArrayList(Component) = null,
    contours: ?std.ArrayList(Contour) = null,
};

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#component
pub const Component = struct {
    // Maybe a Glif, but we may not have loaded this Glif yet
    // TODO: check in a validate function?
    base: []const u8 = undefined,

    x_scale: f64 = 1,
    xy_scale: f64 = 0,
    yx_scale: f64 = 0,
    y_scale: f64 = 1,

    x_offset: f64 = 0,
    y_offset: f64 = 0,

    color: ?Color = null,

    // TODO: should be unique and follow this convention:
    // https://unifiedfontobject.org/versions/ufo3/conventions/#identifiers
    identifier: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#contour
pub const Contour = struct {
    // TODO: should be unique and follow this convention:
    // https://unifiedfontobject.org/versions/ufo3/conventions/#identifiers
    identifier: ?[]const u8 = null,

    /// Must follow the rules specified in PointType
    points: std.ArrayList(Point) = undefined,
};

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#point
pub const Point = struct {
    x: f64 = undefined,
    y: f64 = undefined,

    type: PointType = .offcurve,

    /// This attribute must only be given when type indicates the point
    /// is on-curve: all point types except offcurve.
    /// In a .glif file, its value is either “yes” or “no”.
    smooth: bool = false,

    name: ?[]const u8 = null,

    // TODO: should be unique and follow this convention:
    // https://unifiedfontobject.org/versions/ufo3/conventions/#identifiers
    identifier: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/glyphs/glif/#point-types
pub const PointType = enum {
    /// A point of this type must be the first in a contour
    move,

    /// The previous point must not be an offcurve.
    line,

    /// The next point is either a curve or a qcurve
    offcurve,

    curve,
    qcurve,
};

pub fn deinit(self: *Glif) void {
    self.codepoints.deinit();
    self.guidelines.deinit();
    self.anchors.deinit();

    if (self.outline) |outline| {
        if (outline.components) |c| c.deinit();

        if (outline.contours) |c| {
            for (c.items) |contour| {
                contour.points.deinit();
            }
            c.deinit();
        }
    }

    logger.debug("{} was successfully deinited", .{Glif});
}

/// Called recursively by the layer parser
pub fn fromContent(option: CreateOption, allocator: std.mem.Allocator) !Glif {
    var doc = try xml.Doc.fromFile(option.path);
    defer doc.deinit();

    const root_node = try doc.getRootElement();

    var glif = try root_node.glifToStruct(allocator);

    // Never trust a glif name, use the one defined in contents.plist
    glif.name = option.name;

    // TODO: Not sure to keep that here
    glif.path = option.path;

    return glif;
}

pub const CreateOption = struct {
    name: []const u8 = undefined,
    path: []const u8 = undefined,
};

pub fn codepointFromString(str: []const u8) !u21 {
    return try std.fmt.parseInt(u21, str, 16);
}

pub const contents_file = "contents.plist";

const std = @import("std");
const xml = @import("xml.zig");
const logger = @import("Logger.zig").scopped(.Glif);

const Color = @import("Color.zig");
