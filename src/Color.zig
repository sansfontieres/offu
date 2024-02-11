//! A color definition is defined as a string containing a
//! comma-separated sequence of four integers or floats between 0 and 1.
//! The color is always specified in the sRGB color space.
//!
//! https://unifiedfontobject.org/versions/ufo3/conventions/#colors
pub const Color = @This();
/// Positive integer or float
red: f64,

/// Positive integer or float
green: f64,

/// Positive integer or float
blue: f64,

/// Positive integer or float
alpha: f64,

/// TODO: Move back into Layer.zig once work on lib starts
pub fn fromLayerInfo(doc: xml.Doc) !?Color {
    var color: ?Color = null;

    const root_node = try doc.getRootElement();
    const dict_node = root_node.findChild("dict").?;

    var node_it = try dict_node.iterateDict();
    while (node_it.next()) |xml_field| {
        const field_content = xml_field.getContent() orelse return xml.Node.Error.EmptyElement;
        const value_node = node_it.next() orelse return xml.Node.Error.NoValue;

        if (std.mem.eql(u8, field_content, "color")) {
            const color_str = value_node.getContent().?;
            color = try Color.fromString(color_str);
        } else continue;
    }

    return color;
}

pub fn fromString(str: []const u8) !Color {
    var red: f64 = undefined;
    var green: f64 = undefined;
    var blue: f64 = undefined;
    var alpha: f64 = undefined;

    var chans_str = std.mem.split(u8, str, ",");

    var idx: usize = 0;
    while (chans_str.next()) |chan_str| : (idx += 1) {
        const clean_str = std.mem.trim(u8, chan_str, &std.ascii.whitespace);
        const chan = try std.fmt.parseFloat(f64, clean_str);

        switch (idx) {
            0 => red = chan,
            1 => green = chan,
            2 => blue = chan,
            3 => alpha = chan,

            else => unreachable,
        }
    }

    return Color{ .red = red, .green = green, .blue = blue, .alpha = alpha };
}

pub fn toString(self: *Color) ![]const u8 {
    var buffer: [1024]u8 = undefined;
    return try std.fmt.bufPrint(buffer[0..], "{d},{d},{d},{d}", .{
        self.red,
        self.green,
        self.blue,
        self.alpha,
    });
}

const std = @import("std");
const xml = @import("xml.zig");

test "Color can be parsed from string" {
    const color = try Color.fromString("1,0.5,0,0.3");

    try std.testing.expectEqual(1, color.red);
    try std.testing.expectEqual(0.5, color.green);
    try std.testing.expectEqual(0, color.blue);
    try std.testing.expectEqual(0.3, color.alpha);

    const color_trimmed = try Color.fromString("0.8 , 1,         0.1,\t1");
    try std.testing.expectEqual(0.8, color_trimmed.red);
    try std.testing.expectEqual(1, color_trimmed.green);
    try std.testing.expectEqual(0.1, color_trimmed.blue);
    try std.testing.expectEqual(1, color_trimmed.alpha);
}

test "Color can output a valid string" {
    const string = "1,.1,1,.5";
    const padded_string = "1,0.1,1,0.5";
    var color = try Color.fromString(string);
    const new_string = try color.toString();

    try std.testing.expectEqualStrings(padded_string, new_string);
}
