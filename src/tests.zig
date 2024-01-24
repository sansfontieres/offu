const builtin = @import("builtin");

comptime {
    if (builtin.is_test) {
        _ = @import("offu.zig");
        _ = @import("FontInfo.zig");
        _ = @import("MetaInfo.zig");
        _ = @import("xml/Doc.zig");
    }
}
