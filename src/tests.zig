const builtin = @import("builtin");

comptime {
    if (builtin.is_test) {
        _ = @import("offu.zig");
        _ = @import("Info.zig");
        _ = @import("MetaInfo.zig");
    }
}
