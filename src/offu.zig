//! A [Unified Font Object] (v3) library.
//!
//! Supports:
//! * Reading: No.
//! * Writing: No.
//!
//! Under the hood, Offu heavily relies on libxml2.
//!
//! [Unified Font Object]: https://unifiedfontobject.org/versions/ufo3/
const std = @import("std");

pub const Info = @import("Info.zig");
pub const MetaInfo = @import("MetaInfo.zig");
