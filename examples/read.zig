const std = @import("std");
const offu = @import("offu");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Memory leak");
    }

    {
        var font_info_doc = try offu.xml.Doc.fromFile(
            "test_inputs/Untitled.ufo/fontinfo.plist",
        );
        defer font_info_doc.deinit();

        var font_info = try offu.FontInfo.initFromDoc(&font_info_doc, allocator);
        defer font_info.deinit(allocator);

        try font_info.validate();
    }

    {
        var meta_info_doc = try offu.xml.Doc.fromFile(
            "test_inputs/Untitled.ufo/metainfo.plist",
        );
        defer meta_info_doc.deinit();

        var meta_info = try offu.MetaInfo.initFromDoc(&meta_info_doc, allocator);

        try meta_info.validate();
    }
}
