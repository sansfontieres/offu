//! The struct holding every pieces of an UFO components together
pub const Ufo = @This();

path: []const u8,

font_info: ?FontInfo,
font_info_doc: ?xml.Doc,

meta_info: MetaInfo,
meta_info_doc: xml.Doc,

pub const CreateOptions = struct {
    //
    font_info_file: ?[]const u8 = null,
    meta_info_file: ?[]const u8 = null,
};

pub fn init(
    path: []const u8,
    allocator: std.mem.Allocator,
    options: CreateOptions,
) !Ufo {
    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();

    var font_info: ?FontInfo = null;
    var font_info_doc: ?xml.Doc = null;

    var meta_info: MetaInfo = undefined;
    var meta_info_doc: xml.Doc = undefined;

    font_info_doc = blk: {
        var font_info_file: []const u8 = FontInfo.font_info_file;
        if (options.font_info_file) |option| font_info_file = option;

        dir.access(font_info_file, .{}) catch {
            logger.info(
                "Failed to find {s}, skipping {}",
                .{ font_info_file, FontInfo },
            );
            break :blk null;
        };

        const full_path = try std.fs.path.join(
            allocator,
            &[_][]const u8{ path, font_info_file },
        );
        defer allocator.free(full_path);

        break :blk try xml.Doc.fromFile(full_path);
    };

    if (font_info_doc) |*doc| {
        font_info = try FontInfo.initFromDoc(doc, allocator);
    }

    meta_info_doc = blk: {
        var meta_info_file: []const u8 = MetaInfo.meta_info_file;
        if (options.meta_info_file) |option| meta_info_file = option;

        const full_path = try std.fs.path.join(
            allocator,
            &[_][]const u8{ path, meta_info_file },
        );
        defer allocator.free(full_path);

        break :blk try xml.Doc.fromFile(full_path);
    };

    meta_info = try MetaInfo.initFromDoc(&meta_info_doc, allocator);

    logger.info(
        "Loaded {s} successfully",
        .{path},
    );
    return Ufo{
        .path = path,

        .font_info = font_info,
        .font_info_doc = font_info_doc,

        .meta_info = meta_info,
        .meta_info_doc = meta_info_doc,
    };
}

pub fn deinit(self: *Ufo, allocator: std.mem.Allocator) void {
    if (self.font_info) |*font_info| {
        font_info.deinit(allocator);
        self.font_info_doc.?.deinit();
    }

    self.meta_info_doc.deinit();
}

const std = @import("std");
const xml = @import("xml.zig");
const FontInfo = @import("FontInfo.zig");
const MetaInfo = @import("MetaInfo.zig");
const LayerContents = @import("LayerContents.zig");
const logger = @import("offu.zig").logger;
