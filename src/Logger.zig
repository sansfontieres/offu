//! Downgrades log.err and log.warn to the log.info level to not trip
//! tests errors
pub const Logger = @This();

pub fn scopped(comptime scope: @Type(.EnumLiteral)) type {
    if (builtin.is_test)
        return struct {
            pub const logger = std.log.scoped(scope);
            pub const err = warn;
            pub const warn = info;
            pub const info = logger.info;
            pub const debug = logger.debug;
        }
    else
        return std.log.scoped(scope);
}

const std = @import("std");
const builtin = @import("builtin");
