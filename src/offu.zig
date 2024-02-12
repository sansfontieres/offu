//! A [Unified Font Object] (v3) library.
//!
//! Supports:
//! * Reading: Almost there.
//! * Writing: No.
//!
//! [Unified Font Object]: https://unifiedfontobject.org/versions/ufo3/

pub const init = Ufo.init;
pub const deinit = Ufo.deinit;

pub const xml = @import("xml.zig");
pub const Ufo = @import("Ufo.zig");
pub const FontInfo = @import("FontInfo.zig");
pub const MetaInfo = @import("MetaInfo.zig");
pub const LayerContents = @import("LayerContents.zig");
pub const Layer = @import("Layer.zig");
pub const Glif = @import("Glif.zig");
pub const Color = @import("Color.zig");

// Missing
// * groups.plist
// * kerning.plist
// * features.fea

// TODO
// https://unifiedfontobject.org/versions/ufo3/features.fea/
// https://adobe-type-tools.github.io/afdko/OpenTypeFeatureFileSpecification.html
// pub const Feature = @import("Feature.zig");

pub const logger = @import("Logger.zig").scopped(.Offu);
pub const authoring_name = "com.sansfontieres.offu";
