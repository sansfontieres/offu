//! A [Unified Font Object] (v3) library.
//!
//! Supports:
//! * Reading: No.
//! * Writing: No.
//!
//! [Unified Font Object]: https://unifiedfontobject.org/versions/ufo3/

const std = @import("std");

pub const init = Ufo.init;
pub const deinit = Ufo.deinit;

pub const xml = @import("xml.zig");
pub const Ufo = @import("Ufo.zig");
pub const FontInfo = @import("FontInfo.zig");
pub const MetaInfo = @import("MetaInfo.zig");
pub const LayerContents = @import("LayerContents.zig");

pub const logger = @import("Logger.zig").scopped(.offu);
