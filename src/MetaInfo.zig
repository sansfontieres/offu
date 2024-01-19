//! Representation of [metainfo.plist]
//!
//! This file contains metadata about the UFO. This file is required and
//! so is MetaInfo
//!
//! [metainfo.plist]: https://unifiedfontobject.org/versions/ufo3/metainfo.plist/
const std = @import("std");
const xml = @import("libxml2.zig");

const meta_info_default_creator = "com.sansfontieres.offu";

const MetaInfo = @This();

/// The application or library that created the UFO. This should follow
/// a reverse domain naming scheme. For example, org.robofab.ufoLib.
creator: ?[]const u8 = meta_info_default_creator,

/// The major version number of the UFO format. 3 for UFO 3. Required.
/// (and we only support UFO3 here)
format_version: usize = 3,

/// Optional if 0
format_version_minor: ?usize = null,

test "serialize" {
    // TODO
    const xml_str =
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
        \\"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        \\<plist version="1.0">
        \\<dict>
        \\  <key>creator</key>
        \\  <string>org.robofab.ufoLib</string>
        \\  <key>formatVersion</key>
        \\  <integer>3</integer>
        \\  <key>formatVersionMinor</key>
        \\  <integer>0</integer>
        \\</dict>
        \\</plist>
    ;
    const reader = xml.xmlReaderForMemory(
        xml_str,
        @intCast(xml_str.len),
        null,
        "utf-8",
        0,
    );

    while (true) {
        switch (xml.xmlTextReaderRead(reader)) {
            -1 => return error.ParseFailed,
            0 => break,
            else => {
                //
            },
        }
    }

    if (xml.xmlTextReaderClose(reader) == -1) {
        return error.ParseFailed;
    }
}

test "deserialize" {
    // TODO
}
