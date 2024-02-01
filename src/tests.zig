comptime {
    if (@import("builtin").is_test) {
        _ = @import("offu.zig");
        _ = @import("xml/Doc.zig");
        _ = @import("xml/Node.zig");
        _ = @import("FontInfo.zig");
        _ = @import("MetaInfo.zig");
        _ = @import("LayerContents.zig");
    }
}
