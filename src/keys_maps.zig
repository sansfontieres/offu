const std = @import("std");

pub const MetaInfo = @import("MetaInfo.zig");
pub const FontInfo = @import("FontInfo.zig");

pub fn StructKeyMap(comptime T: anytype) !type {
    return switch (T) {
        MetaInfo => MetaInfoKeyMap,
        FontInfo => FontInfoKeyMap,
        FontInfo.GaspRangeRecord => GaspRangeRecordKeyMap,
        FontInfo.NameRecord => NameRecordKeyMap,
        FontInfo.FamilyClass => FamilyClassKeyMap,
        FontInfo.WoffMetadataUniqueID => WoffMetadataUniqueIDKeyMap,
        FontInfo.WoffMetadataVendor => WoffMetadataVendorKeyMap,
        FontInfo.WoffMetadataCredit => WoffMetadataCreditKeyMap,
        FontInfo.WoffMetadataDescription => WoffMetadataDescriptionKeyMap,
        FontInfo.WoffMetadataLicense => WoffMetadataLicenseKeyMap,
        FontInfo.WoffMetadataCopyright => WoffMetadataCopyrightKeyMap,
        FontInfo.WoffMetadataTrademark => WoffMetadataTrademarkKeyMap,
        FontInfo.WoffMetadataText => WoffMetadataTextKeyMap,
        FontInfo.WoffMetadataLicensee => WoffMetadataLicenseeKeyMap,
        FontInfo.WoffMetadataExtension => WoffMetadataExtensionKeyMap,
        FontInfo.WoffMetadataExtensionName => WoffMetadataExtensionNameKeyMap,
        FontInfo.WoffMetadataExtensionItem => WoffMetadataExtensionItemKeyMap,
        FontInfo.WoffMetadataExtensionValue => WoffMetadataExtensionValueKeyMap,
        FontInfo.Guideline => GuidelineKeyMap,

        else => return error.UnknownStruct,
    };
}

pub const MetaInfoKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(MetaInfo),
    .{
        .{ "creator", .creator },
        .{ "formatVersion", .format_version },
        .{ "formatVersionMinor", .format_version_minor },
    },
);

pub const FontInfoKeyMap = blk: {
    @setEvalBranchQuota(2700);
    break :blk std.ComptimeStringMap(
        std.meta.FieldEnum(FontInfo),
        .{
            .{ "familyName", .family_name },
            .{ "styleName", .style_name },
            .{ "styleMapFamilyName", .style_map_family_name },
            .{ "styleMapStyleName", .style_map_style_name },

            .{ "versionMajor", .version_major },

            .{ "versionMinor", .version_minor },
            .{ "year", .year },
            .{ "copyright", .copyright },
            .{ "trademark", .trademark },

            .{ "unitsPerEm", .units_per_em },

            .{ "descender", .descender },

            .{ "xHeight", .x_height },

            .{ "capHeight", .cap_height },

            .{ "ascender", .ascender },

            .{ "italicAngle", .italic_angle },

            .{ "note", .note },

            .{ "openTypeGaspRangeRecords", .opentype_gasp_range_records },

            .{ "openTypeHeadCreated", .opentype_head_created },
            .{ "openTypeHeadLowestRecPPEM", .opentype_head_lowest_rec_ppem },
            .{ "openTypeHeadFlags", .opentype_head_flags },

            .{ "openTypeHheaAscender", .opentype_hhea_ascender },
            .{ "openTypeHheaDescender", .opentype_hhea_descender },
            .{ "openTypeHheaLineGap", .opentype_hhea_line_gap },
            .{ "openTypeHheaCaretSlopeRise", .opentype_hhea_caret_slope_rise },
            .{ "openTypeHheaCaretSlopeRun", .opentype_hhea_caret_slope_run },
            .{ "openTypeHheaCaretOffset", .opentype_hhea_caret_offset },

            .{ "openTypeNameDesigner", .opentype_name_designer },
            .{ "openTypeNameDesignerURL", .opentype_name_designer_url },
            .{ "openTypeNameManufacturer", .opentype_name_manufacturer },
            .{ "openTypeNameManufacturerURL", .opentype_name_manufacturer_url },
            .{ "openTypeNameLicense", .opentype_name_license },
            .{ "openTypeNameLicenseURL", .opentype_name_license_url },
            .{ "openTypeNameVersion", .opentype_name_version },
            .{ "openTypeNameUniqueID", .opentype_name_unique_id },
            .{ "openTypeNameDescription", .opentype_name_description },
            .{ "openTypeNamePreferredFamilyName", .opentype_name_preferred_family_name },
            .{ "openTypeNamePreferredSubfamilyName", .opentype_name_preferred_subfamily_name },
            .{ "openTypeNameCompatibleFullName", .opentype_name_compatible_fullname },
            .{ "openTypeNameSampleText", .opentype_name_sample_text },
            .{ "openTypeNameWWSFamily_name", .opentype_name_wws_family_name },
            .{ "openTypeNameWWSSubfamilyName", .opentype_name_wws_subfamily_name },
            .{ "openTypeNameRecords", .opentype_name_records },

            .{ "openTypeOS2WidthClass", .opentype_os2_width_class },
            .{ "openTypeOS2WeightClass", .opentype_os2_weight_class },
            .{ "openTypeOS2Selection", .opentype_os2_selection },
            .{ "openTypeOS2VendorID", .opentype_os2_vendor_id },
            .{ "openTypeOS2Panose", .opentype_os2_panose },
            .{ "openTypeOS2FamilyClass", .opentype_os2_family_class },
            .{ "openTypeOS2UnicodeRanges", .opentype_os2_unicode_ranges },
            .{ "openTypeOS2CodePageRanges", .opentype_os2_codepage_ranges },
            .{ "openTypeOS2TypoAscender", .opentype_os2_typo_ascender },
            .{ "openTypeOS2TypoDescender", .opentype_os2_typo_descender },
            .{ "openTypeOS2TypoLineGap", .opentype_os2_typo_line_gap },
            .{ "openTypeOS2WinAscent", .opentype_os2_win_ascent },
            .{ "openTypeOS2WinDescent", .opentype_os2_win_descent },
            .{ "openTypeOS2Type", .opentype_os2_type },
            .{ "openTypeOS2SubscriptXSize", .opentype_os2_subscript_x_size },
            .{ "openTypeOS2SubscriptYSize", .opentype_os2_subscript_y_size },
            .{ "openTypeOS2SubscriptXOffset", .opentype_os2_subscript_x_offset },
            .{ "openTypeOS2SubscriptYOffset", .opentype_os2_subscript_y_offset },
            .{ "openTypeOS2SuperscriptXSize", .opentype_os2_superscript_x_size },
            .{ "openTypeOS2SuperscriptYSize", .opentype_os2_superscript_y_size },
            .{ "openTypeOS2SuperscriptXOffset", .opentype_os2_superscript_x_offset },
            .{ "openTypeOS2SuperscriptYOffset", .opentype_os2_superscript_y_offset },
            .{ "openTypeOS2StrikeoutSize", .opentype_os2_strikeout_size },
            .{ "openTypeOS2StrikeoutPosition", .opentype_os2_strikeout_position },

            .{ "openTypeVheaVertTypoAscender", .opentype_vhea_vert_typo_ascender },
            .{ "openTypeVheaVertTypoDescender", .opentype_vhea_vert_typo_descender },
            .{ "openTypeVheaVertTypoLineGap", .opentype_vhea_vert_typo_line_gap },
            .{ "openTypeVheaCaretSlopeRise", .opentype_vhea_caret_slope_rise },
            .{ "openTypeVheaCaretSlopeRun", .opentype_vhea_caret_slope_run },
            .{ "openTypeVheaCaretOffset", .opentype_vhea_caret_offset },

            .{ "postscriptFontName", .postscript_font_name },
            .{ "postscriptFullName", .postscript_full_name },
            .{ "postscriptSlantAngle", .postscript_slant_angle },
            .{ "postscriptUniqueID", .postscript_unique_id },
            .{ "postscriptUnderlineThickness", .postscript_underline_thickness },
            .{ "postscriptUnderlinePosition", .postscript_underline_position },
            .{ "postscriptIsFixedPitch", .postscript_is_fixed_pitch },
            .{ "postscriptBlueValues", .postscript_blue_values },
            .{ "postscriptOtherBlues", .postscript_other_blues },
            .{ "postscriptFamilyBlues", .postscript_family_blues },
            .{ "postscriptFamilyOtherBlues", .postscript_family_other_blues },
            .{ "postscriptStemSnapH", .postscript_stem_snap_h },
            .{ "postscriptStemSnapV", .postscript_stem_snap_v },
            .{ "postscriptBlueFuzz", .postscript_blue_fuzz },
            .{ "postscriptBlueShift", .postscript_blue_shift },
            .{ "postscriptBlueScale", .postscript_blue_scale },
            .{ "postscriptForceBold", .postscript_force_bold },
            .{ "postscriptDefaultWidthX", .postscript_default_width_x },
            .{ "postscriptNominalWidthX", .postscript_nominal_width_x },
            .{ "postscriptWeightName", .postscript_weight_name },
            .{ "postscriptDefaultCharacter", .postscript_default_character },
            .{ "postscriptWindowsCharacterSet", .postscript_windows_character_set },

            .{ "macintoshFONDFamilyID", .macintosh_fond_family_id },
            .{ "macintoshFONDName", .macintosh_fond_name },

            .{ "woffMajorVersion", .woff_major_version },
            .{ "woffMinorVersion", .woff_minor_version },
            .{ "woffMetadataUniqueid", .woff_metadata_unique_id },
            .{ "woffMetadataVendor", .woff_metadata_vendor },
            .{ "woffMetadataCredits", .woff_metadata_credits },
            .{ "woffMetadataDescription", .woff_metadata_description },
            .{ "woffMetadataLicense", .woff_metadata_license },
            .{ "woffMetadataCopyright", .woff_metadata_copyright },
            .{ "woffMetadataTrademark", .woff_metadata_trademark },
            .{ "woffMetadataLicensee", .woff_metadata_licensee },
            .{ "woffMetadataExtensions", .woff_metadata_extensions },

            .{ "guidelines", .guidelines },
        },
    );
};

pub const GaspRangeRecordKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.GaspRangeRecord),
    .{
        .{ "rangeMaxPPEM", .range_max_ppem },
        .{ "rangeGaspBehavior", .range_gasp_behavior },
    },
);

pub const NameRecordKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.NameRecord),
    .{
        .{ "nameID", .name_id },
        .{ "platformID", .platform_id },
        .{ "encodingID", .encoding_id },
        .{ "languageID", .language_id },
        .{ "string", .string },
    },
);

pub const FamilyClassKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.FamilyClass),
    .{
        .{ "class", .class },
        .{ "subClass", .sub_class },
    },
);

pub const WoffMetadataUniqueIDKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataUniqueID),
    .{
        .{ "id", .id },
    },
);

pub const WoffMetadataVendorKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataVendor),
    .{
        .{ "name", .name },
        .{ "url", .url },
        .{ "dir", .dir },
        .{ "class", .class },
        .{ "role", .role },
    },
);

pub const WoffMetadataCreditKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataCredit),
    .{
        .{ "name", .name },
        .{ "url", .url },
        .{ "dir", .dir },
        .{ "class", .class },
        .{ "role", .role },
    },
);

pub const WoffMetadataDescriptionKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataDescription),
    .{
        .{ "url", .url },
        .{ "text", .text },
    },
);

pub const WoffMetadataLicenseKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataLicense),
    .{
        .{ "url", .url },
        .{ "id", .id },
        .{ "text", .text },
    },
);

pub const WoffMetadataCopyrightKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataCopyright),
    .{
        .{ "text", .text },
    },
);

pub const WoffMetadataTrademarkKeyMap = WoffMetadataCopyrightKeyMap;

pub const WoffMetadataTextKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataText),
    .{
        .{ "text", .text },
        .{ "language", .language },
        .{ "dir", .dir },
        .{ "class", .class },
    },
);

pub const WoffMetadataLicenseeKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataLicensee),
    .{
        .{ "id", .id },
        .{ "names", .names },
        .{ "items", .items },
    },
);

pub const WoffMetadataExtensionItemKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataExtensionItem),
    .{
        .{ "id", .id },
        .{ "names", .names },
        .{ "values", .values },
    },
);

pub const WoffMetadataExtensionKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.WoffMetadataExtension),
    .{
        .{ "id", .id },
        .{ "names", .names },
        .{ "items", .items },
    },
);

pub const WoffMetadataExtensionNameKeyMap = WoffMetadataTextKeyMap;

pub const WoffMetadataExtensionValueKeyMap = WoffMetadataTextKeyMap;

pub const GuidelineKeyMap = std.ComptimeStringMap(
    std.meta.FieldEnum(FontInfo.Guideline),
    .{
        .{ "x", .x },
        .{ "y", .y },
        .{ "angle", .angle },
        .{ "name", .name },
        .{ "color", .color },
        .{ "identifier", .identifier },
    },
);
