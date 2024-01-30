//! Representation of [fontinfo.plist]
//!
//! fontinfo.plist is optional for a valid UFO, and so is Info all of
//! its fields too, neat!
//!
//! [fontinfo.plist]: https://unifiedfontobject.org/versions/ufo3/fontinfo.plist
const FontInfo = @This();

const std = @import("std");
const xml = @import("xml/main.zig");
const logger = std.log.scoped(.fontinfo);

pub const IntOrFloat = f64;

family_name: ?[]const u8 = null,
style_name: ?[]const u8 = null,
style_map_family_name: ?[]const u8 = null,
style_map_style_name: ?StyleMapStyle = null,

/// Specified as integer, but negative versions?
version_major: ?usize = null,

version_minor: ?usize = null,
year: ?isize = null, // Building computer fonts since XXXX B.C.
copyright: ?[]const u8 = null,
trademark: ?[]const u8 = null,

/// Positive integer or float
units_per_em: ?IntOrFloat = null,

/// Integer or float
descender: ?IntOrFloat = null,

/// Integer or float
x_height: ?IntOrFloat = null,

/// Integer or float
cap_height: ?IntOrFloat = null,

/// Integer or float
ascender: ?IntOrFloat = null,

/// Integer or float
italic_angle: ?IntOrFloat = null,

note: ?[]const u8 = null,

/// Must be sorted in ascending order based on the `range_max_ppem` value of
/// the record with a sentinel value of 0xFFFF
// TODO: Implement a tidy function which would sort this among things.
opentype_gasp_range_records: ?std.MultiArrayList(GaspRangeRecord) = null,

opentype_head_created: ?[]const u8 = null,
opentype_head_lowest_rec_ppem: ?usize = null,
opentype_head_flags: ?std.ArrayList(HeadFlags) = null,

opentype_hhea_ascender: ?isize = null,
opentype_hhea_descender: ?isize = null,
opentype_hhea_line_gap: ?isize = null,
opentype_hhea_caret_slope_rise: ?isize = null,
opentype_hhea_caret_slope_run: ?isize = null,
opentype_hhea_caret_offset: ?isize = null,

opentype_name_designer: ?[]const u8 = null,
opentype_name_designer_url: ?[]const u8 = null,
opentype_name_manufacturer: ?[]const u8 = null,
opentype_name_manufacturer_url: ?[]const u8 = null,
opentype_name_license: ?[]const u8 = null,
opentype_name_license_url: ?[]const u8 = null,
opentype_name_version: ?[]const u8 = null,
opentype_name_unique_id: ?[]const u8 = null,
opentype_name_description: ?[]const u8 = null,
opentype_name_preferred_family_name: ?[]const u8 = null,
opentype_name_preferred_subfamily_name: ?[]const u8 = null,
opentype_name_compatible_fullname: ?[]const u8 = null,
opentype_name_sample_text: ?[]const u8 = null,
opentype_name_wws_family_name: ?[]const u8 = null,
opentype_name_wws_subfamily_name: ?[]const u8 = null,
opentype_name_records: ?std.ArrayList(NameRecord) = null,

opentype_os2_width_class: ?WidthClass = null,
opentype_os2_height_class: ?usize = null,
opentype_os2_selection: ?std.ArrayList(Selection) = null,

/// Must be 4 characters long
opentype_os2_vendor_id: ?[]const u8 = null,

opentype_os2_panose: ?Panose = null,
opentype_os2_family_class: ?FamilyClass = null,
opentype_os2_unicode_ranges: ?std.ArrayList(u8) = null,
opentype_os2_codepage_ranges: ?std.ArrayList(u8) = null,
opentype_os2_typo_ascender: ?isize = null,
opentype_os2_typo_descender: ?isize = null,
opentype_os2_typo_line_gap: ?isize = null,
opentype_os2_win_ascent: ?usize = null,
opentype_os2_win_descent: ?usize = null,
opentype_os2_type: ?std.ArrayList(u8) = null,
opentype_os2_subscript_x_size: ?isize = null,
opentype_os2_subscript_y_size: ?isize = null,
opentype_os2_subscript_x_offset: ?isize = null,
opentype_os2_subscript_y_offset: ?isize = null,
opentype_os2_superscript_x_size: ?isize = null,
opentype_os2_superscript_y_size: ?isize = null,
opentype_os2_superscript_x_offset: ?isize = null,
opentype_os2_superscript_y_offset: ?isize = null,
opentype_os2_strikeout_size: ?isize = null,
opentype_os2_strikeout_position: ?isize = null,

opentype_vhea_vert_typo_ascender: ?isize = null,
opentype_vhea_vert_typo_descender: ?isize = null,
opentype_vhea_vert_typo_line_gap: ?isize = null,
opentype_vhea_caret_slope_rise: ?isize = null,
opentype_vhea_caret_slope_run: ?isize = null,
opentype_vhea_caret_offset: ?isize = null,

postscript_font_name: ?[]const u8 = null,
postscript_full_name: ?[]const u8 = null,

/// Integer or float
postscript_slant_angle: ?IntOrFloat = null,

postscript_unique_id: ?isize = null,

/// Integer or float
postscript_underline_thickness: ?IntOrFloat = null,

/// Integer or float
postscript_underline_position: ?IntOrFloat = null,

postscript_is_fixed_pitch: ?bool = null,

/// Should hold 14 items
postscript_blue_values: ?std.ArrayList(isize) = null,

/// Should hold 10 items
postscript_other_blues: ?std.ArrayList(isize) = null,

/// Should hold 14 items
postscript_family_blues: ?std.ArrayList(isize) = null,

/// Should hold 10 items
postscript_family_other_blues: ?std.ArrayList(isize) = null,

/// Integer or float
postscript_stem_snap_h: ?std.ArrayList(IntOrFloat) = null,

/// Integer or float
postscript_stem_snap_v: ?std.ArrayList(IntOrFloat) = null,

/// Integer or float
postscript_blue_fuzz: ?IntOrFloat = null,

/// Integer or float
postscript_blue_shift: ?IntOrFloat = null,

postscript_blue_scale: ?f32 = null,
postscript_force_bold: ?bool = null,

/// Integer or float
postscript_default_width_x: ?IntOrFloat = null,

/// Integer or float
postscript_nominal_width_x: ?IntOrFloat = null,

postscript_weight_name: ?[]const u8 = null,
postscript_default_character: ?[]const u8 = null,
postscript_windows_character_set: ?PostScriptWindowsCharacterSet = null,

macintosh_fond_family_id: ?isize = null,
macintosh_fond_name: ?[]const u8 = null,

woff_major_version: ?usize = null,
woff_minor_version: ?usize = null,
woff_metadata_unique_id: ?WoffMetadataUniqueID = null,
woff_metadata_vendor: ?WoffMetadataVendor = null,
woff_metadata_credits: ?WoffMetadataCredit = null,
woff_metadata_description: ?WoffMetadataDescription = null,
woff_metadata_license: ?WoffMetadataLicense = null,
woff_metadata_copyright: ?WoffMetadataCopyright = null,
woff_metadata_trademark: ?WoffMetadataTrademark = null,
woff_metadata_licensee: ?WoffMetadataLicensee = null,
woff_metadata_extensions: ?std.MultiArrayList(WoffMetadataExtension) = null,

guidelines: ?std.ArrayList(Guideline) = null,

/// Since style_map_style_name is a limited set of case sensitive strings,
/// we (de)serialize it to/from an enum.
pub const StyleMapStyle = enum {
    regular,
    bold,
    italic,
    @"bold italic",

    pub fn fromString(str: []const u8) !StyleMapStyle {
        return std.meta.stringToEnum(
            StyleMapStyle,
            str,
        ) orelse FontInfoError.InvalidStyleMapName;
    }

    pub fn toString(self: StyleMapStyle) []const u8 {
        return @tagName(self);
    }
};

/// http://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#gasp-range-record-format
pub const GaspRangeRecord = struct {
    /// The upper limit of the range, in PPEM.
    range_max_ppem: usize,

    range_gasp_behavior: std.ArrayList(GaspBehavior),
};

/// http://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#rangegaspbehavior-bits
pub const GaspBehavior = enum(u8) {
    /// Use gridfitting
    gridfit = 0,

    /// Use grayscale rendering
    dogray,

    /// Use gridfitting with ClearType symmetric smoothing
    symmetric_gridfit,

    /// Use multi-axis smoothing with ClearType
    symmetric_smoothing,
};

/// https://learn.microsoft.com/en-us/typography/opentype/spec/head
pub const HeadFlags = enum(u8) {
    /// Baseline at y=0
    baseline = 0,

    /// Left sidebearing at x=0
    sidebearing,

    /// Instructions may depends on point size
    point_size_dependent,

    /// Force PPEM to integer value
    force_ppem_to_int,

    /// Instructions may alter advance width
    alter_awidth,

    /// Font data is lossless
    lossless = 11,

    /// Font converted (produce compatible metrics).
    converted,

    ///  Font optimized for ClearType™
    o_cleartype,

    /// Last Resort font
    last_reset,
};

/// Records should have a unique nameID, platformID, encodingID and
/// languageID combination. In cases where a duplicate is found, the
/// last occurrence of the nameID, platformID, encodingID and languageID
/// combination must be taken as the value.
/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#name-record-format
pub const NameRecord = struct {
    name_id: usize,
    platform_id: usize,
    encoding_id: usize,
    language_id: usize,
    string: []const u8,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#opentype-os2-table-fields
/// The OpenType OS/2 specification have more details
/// https://learn.microsoft.com/en-us/typography/opentype/spec/os2#uswidthclass
pub const WidthClass = enum(u8) {
    /// 50% of normal
    ultra_condensed = 1,

    /// 62.5% of normal
    extra_condensed,

    /// 75% of normal
    condensed,

    /// 87.5% of normal
    semi_condensed,

    /// Normal
    medium,

    /// 112.5% of normal
    semi_expanded,

    /// 125% of normal
    expanded,

    /// 150% of normal
    extra_expanded,

    /// 200% of normal
    ultra_expanded,
};

/// Bits 0 (italic), 5 (bold) and 6 (regular) must not be set here.
/// These bits should be taken from the generic style_map_style_name
/// attribute.
/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#opentype-os2-table-fields
pub const Selection = enum(u8) {
    /// Font contains italics or oblique glyphs
    italic = 0,

    /// Glyphs are underscored
    underscore,

    /// Glyphs have their foreground and background reversed
    negative,

    /// Outline (hollow) glyphs
    outlined,

    /// Glyphs are overstruck
    strikeout,

    /// Glyphs are emboldened
    bold,

    /// Glyphs are in the standard weight/style for the font
    regular,

    /// Use OS/2 patterns as metrics
    use_typo_metrics,

    /// Font’s name table consistent with a weight/width/slope family
    wwws,

    /// Font contains oblique glyphs
    oblique,
};

/// Two integers representing the IBM font class and font subclass of
/// the font. The first number, representing the class ID, must be in the
/// range 0-14. The second number, representing the subclass, must be in the
/// range 0-15.
/// http://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#opentype-os2-table-fields
pub const FamilyClass = struct {
    class: u8,
    sub_class: u8,

    fn is_valid(self: @This()) !void {
        if (self.class > 14) return FontInfoError.InvalidFamilyClassID;
        if (self.sub_class > 14) return FontInfoError.InvalidFamilySubClassID;
    }
};

/// The list must contain 10 non-negative integers that represent the
/// setting for each category in the Panose specification. The integers
/// correspond with the option numbers in each of the Panose categories.
/// UFO v2 are not compatible because they allowed each field to be
/// signed integers.
/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#opentype-os2-table-fields
pub const Panose = struct {
    family_type: u8,
    serif_style: u8,
    weight: u8,
    proportion: u8,
    contrast: u8,
    stroke_variation: u8,
    arm_style: u8,
    letterform: u8,
    midline: u8,
    x_height: u8,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#postscriptwindowscharacterset-options
pub const PostScriptWindowsCharacterSet = enum(usize) {
    ansi = 1,
    default,
    symbol,
    macintosh,
    shift_jis,
    hangul,
    hangul_johab,
    gb2312,
    chinese_big5,
    greek,
    turkish,
    vietnamese,
    hebrew,
    arabic,
    baltic,
    bitstream,
    cyrillic,
    thai,
    eastern_european,
    oem,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-unique-id-record
pub const WoffMetadataUniqueID = struct {
    id: []const u8,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-vendor-record
pub const WoffMetadataVendor = struct {
    name: []const u8,
    url: ?[]const u8 = null,
    dir: ?[]const u8 = null,
    class: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-credits-record
pub const WoffMetadataCredit = struct {
    name: []const u8,
    url: ?[]const u8 = null,
    dir: ?[]const u8 = null,
    class: ?[]const u8 = null,
    role: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-description-record
pub const WoffMetadataDescription = struct {
    url: ?[]const u8 = null,
    text: std.ArrayList(WoffMetadataText),
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-license-record
pub const WoffMetadataLicense = struct {
    url: ?[]const u8 = null,
    id: ?[]const u8 = null,
    text: ?std.ArrayList(WoffMetadataText) = null,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-copyright-record
pub const WoffMetadataCopyright = struct {
    text: std.ArrayList(WoffMetadataText),
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-trademark-record
pub const WoffMetadataTrademark = struct {
    text: std.ArrayList(WoffMetadataText),
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-text-record
pub const WoffMetadataText = struct {
    text: []const u8,
    language: ?[]const u8 = null,
    dir: ?[]const u8 = null,
    class: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-licensee-record
pub const WoffMetadataLicensee = struct {
    name: []const u8,
    dir: ?[]const u8 = null,
    class: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-extension-record
pub const WoffMetadataExtension = struct {
    id: ?[]const u8 = null,
    names: std.ArrayList(WoffMetadataExtensionName),
    items: std.ArrayList(WoffMetadataExtensionItem),
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-extension-name-record
pub const WoffMetadataExtensionName = struct {
    text: []const u8,
    language: ?[]const u8 = null,
    dir: ?[]const u8 = null,
    class: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-extension-item-record
pub const WoffMetadataExtensionItem = struct {
    id: ?[]const u8 = null,
    names: std.ArrayList(WoffMetadataExtensionName),
    values: std.ArrayList(WoffMetadataExtensionValue),
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#woff-metadata-extension-value-record
pub const WoffMetadataExtensionValue = struct {
    text: []const u8,
    language: ?[]const u8 = null,
    dir: ?[]const u8 = null,
    class: ?[]const u8 = null,
};

/// https://unifiedfontobject.org/versions/ufo3/fontinfo.plist/#guideline-format
pub const Guideline = struct {
    /// Integer or float
    x: ?IntOrFloat = null,

    /// Integer or float
    y: ?IntOrFloat = null,

    /// Integer or float
    angle: ?IntOrFloat = null,

    name: ?[]const u8 = null,
    color: ?[]const u8 = null,
    identifier: ?[]const u8 = null,
};

const FontInfoError = error{
    InvalidSentinelGaspRange,

    InvalidStyleMapName,
    UnitsPerEmNegative,

    VendorIDTooLong,
    InvalidFamilyClass,
    InvalidFamilyClassID,
    InvalidFamilySubClassID,

    InvalidBlueValues,
    InvalidOtherBlues,
    InvalidFamilyBlues,
    InvalidFamilyOtherBlues,

    MalformedFile,
};

/// Checks if fields, when not null, are correctly defined per the UFO
/// specification
pub fn verification(self: *FontInfo) !bool {
    if (self.opentype_gasp_range_records) |gasp_range_records| {
        const len = gasp_range_records.len;
        if (len > 0) {
            const last_record = gasp_range_records.get(len - 1);
            if (last_record.range_max_ppem != 0xFFFF) {
                return FontInfoError.InvalidSentinelGaspRange;
            }
        }
    }

    if (self.units_per_em) |units_per_em| {
        if (std.math.isPositiveZero(units_per_em))
            return FontInfoError.UnitsPerEmNegative;
    }

    // TODO DATE
    // opentype_head_created:
    // Expressed as a string of the format “YYYY/MM/DD HH:MM:SS”.
    // “YYYY/MM/DD” is year/month/day. The month must be in the range 1-12
    // and the day must be in the range 1-end of month. “HH:MM:SS” is
    // hour:minute:second. The hour must be in the range 0:23. The minute and
    // second must each be in the range 0-59. The timezone is UTC.

    if (self.opentype_os2_vendor_id) |opentype_os2_vendor_id| {
        if (opentype_os2_vendor_id.len > 4)
            return FontInfoError.VendorIDTooLong;
    }

    if (self.opentype_os2_family_class) |opentype_os2_family_class| {
        try opentype_os2_family_class.is_valid();
    }

    if (self.postscript_blue_values) |postscript_blue_values| {
        if (postscript_blue_values.items.len > 14)
            return FontInfoError.InvalidBlueValues;
    }

    if (self.postscript_other_blues) |postscript_other_blues| {
        if (postscript_other_blues.items.len > 10)
            return FontInfoError.InvalidOtherBlues;
    }

    if (self.postscript_family_blues) |postscript_family_blues| {
        if (postscript_family_blues.items.len > 14)
            return FontInfoError.InvalidFamilyBlues;
    }

    if (self.postscript_family_other_blues) |postscript_family_other_blues| {
        if (postscript_family_other_blues.items.len > 10)
            return FontInfoError.InvalidFamilyOtherBlues;
    }

    // TODO: Guidelines colors

    return true;
}

/// Deinits/frees fields of Info
pub fn deinit(self: *FontInfo, allocator: std.mem.Allocator) void {
    if (self.opentype_gasp_range_records) |*opentype_gasp_range_records| {
        for (
            opentype_gasp_range_records.items(.range_gasp_behavior),
        ) |range_gasp_behavior| {
            range_gasp_behavior.deinit();
        }
        opentype_gasp_range_records.deinit(allocator);
    }

    if (self.opentype_head_flags) |opentype_head_flags| {
        opentype_head_flags.deinit();
    }

    if (self.opentype_name_records) |opentype_name_records| {
        opentype_name_records.deinit();
    }

    if (self.opentype_os2_selection) |opentype_os2_selection| {
        opentype_os2_selection.deinit();
    }

    if (self.opentype_os2_unicode_ranges) |opentype_os2_unicode_range| {
        opentype_os2_unicode_range.deinit();
    }

    if (self.opentype_os2_codepage_ranges) |opentype_os2_codepage_range| {
        opentype_os2_codepage_range.deinit();
    }

    if (self.opentype_os2_type) |opentype_os2_type| {
        opentype_os2_type.deinit();
    }

    if (self.postscript_blue_values) |postscript_blue_values| {
        postscript_blue_values.deinit();
    }

    if (self.postscript_other_blues) |postscript_other_blues| {
        postscript_other_blues.deinit();
    }

    if (self.postscript_family_blues) |postscript_family_blues| {
        postscript_family_blues.deinit();
    }

    if (self.postscript_family_other_blues) |postscript_family_other_blues| {
        postscript_family_other_blues.deinit();
    }

    if (self.postscript_stem_snap_h) |postscript_stem_snap_h| {
        postscript_stem_snap_h.deinit();
    }

    if (self.postscript_stem_snap_v) |postscript_stem_snap_v| {
        postscript_stem_snap_v.deinit();
    }

    if (self.woff_metadata_description) |woff_metadata_description| {
        woff_metadata_description.text.deinit();
    }

    if (self.woff_metadata_license) |woff_metadata_license| {
        if (woff_metadata_license.text) |text| {
            text.deinit();
        }
    }

    if (self.woff_metadata_copyright) |woff_metadata_copyright| {
        woff_metadata_copyright.text.deinit();
    }

    if (self.woff_metadata_trademark) |woff_metadata_trademark| {
        woff_metadata_trademark.text.deinit();
    }

    if (self.guidelines) |guidelines| {
        guidelines.deinit();
    }

    if (self.woff_metadata_extensions) |*woff_metadata_extensions| {
        for (
            woff_metadata_extensions.items(.names),
            woff_metadata_extensions.items(.items),
        ) |names, items| {
            names.deinit();
            for (items.items) |item| {
                item.names.deinit();
                item.values.deinit();
            }
        }
        woff_metadata_extensions.deinit(allocator);
    }
}

// This is medieval
pub fn initFromDoc(doc: *xml.Doc, allocator: std.mem.Allocator) !FontInfo {
    const root_node = try doc.getRootElement();
    const dict: ?xml.Doc.Node = root_node.findChild("dict") orelse {
        return FontInfoError.MalformedFile;
    };

    return try dict.?.xmlDictToStruct(allocator, FontInfo);
}

test "Info doesn’t throw errors by default" {
    // And its not a small struct
    var info: FontInfo = .{};
    _ = try info.verification();
}

test "Info deinits all kind of data structures" {
    const test_allocator = std.testing.allocator;
    var info: FontInfo = .{};
    defer info.deinit(test_allocator);

    info.opentype_os2_unicode_ranges = std.ArrayList(u8).init(test_allocator);
    try info.opentype_os2_unicode_ranges.?.append(12);

    var gasp_range_record: GaspRangeRecord = .{
        .range_max_ppem = 0xFFFF,
        .range_gasp_behavior = std.ArrayList(GaspBehavior)
            .init(test_allocator),
    };
    try gasp_range_record.range_gasp_behavior.append(.gridfit);
    try gasp_range_record.range_gasp_behavior.append(.dogray);

    info.opentype_gasp_range_records = std.MultiArrayList(GaspRangeRecord){};
    try info.opentype_gasp_range_records.?.append(test_allocator, gasp_range_record);

    info.opentype_os2_family_class = .{ .class = 1, .sub_class = 2 };

    _ = try info.verification();
}

test "verification() gasp_rang_record" {
    const test_allocator = std.testing.allocator;
    var info: FontInfo = .{};
    defer info.deinit(test_allocator);

    info.opentype_gasp_range_records = std.MultiArrayList(GaspRangeRecord){};

    var gasp_range_record_1: GaspRangeRecord = .{
        .range_max_ppem = 1,
        .range_gasp_behavior = std.ArrayList(GaspBehavior)
            .init(test_allocator),
    };
    try gasp_range_record_1.range_gasp_behavior.append(.gridfit);
    try info.opentype_gasp_range_records.?.append(
        test_allocator,
        gasp_range_record_1,
    );

    try std.testing.expectError(
        FontInfoError.InvalidSentinelGaspRange,
        info.verification(),
    );

    var gasp_range_record_2 = .{
        .range_max_ppem = 0xFFFF,
        .range_gasp_behavior = std.ArrayList(GaspBehavior)
            .init(test_allocator),
    };
    try gasp_range_record_2.range_gasp_behavior.append(.gridfit);
    try info.opentype_gasp_range_records.?.append(
        test_allocator,
        gasp_range_record_2,
    );

    try std.testing.expect(try info.verification());
}

test "deserialize" {
    const test_allocator = std.testing.allocator;

    var doc = try xml.Doc.fromFile("test_inputs/Untitled.ufo/fontinfo.plist");
    defer doc.deinit();

    var font_info = try initFromDoc(&doc, test_allocator);
    defer font_info.deinit(test_allocator);

    _ = try font_info.verification();
}
