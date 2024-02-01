# Offu

A library to parse and edit [Unified Font Objects][UFO] v3 written in Zig.

[![][builds.sr.ht]](https://builds.sr.ht/~romi/offu/commits/front?)
[![][license]](https://git.sr.ht/~romi/offu/tree/front/item/LICENSE)


The goal is to have a layer to build on to have less tools using Python.
I can think of some light tasks as removing non-exporting glyphs,
normalizing and running Q.A. tests on an UFO, etc.

There are still some rough edges (it does not work at all!).  
This library follows Zig master releases.


## Features

No Python.


## Installation

```sh
zig fetch --save git+https://git.sr.ht/~romi/offu#front
```

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const offu_dep = b.dependency("offu", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-project",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("offu", offu_dep);
}
```


## Examples

Browse the `examples` directory.


## Docs

API: https://sansfontieres.com/docs/offu

[UFO]: https://unifiedfontobject.org/versions/ufo3/
[builds.sr.ht]: https://builds.sr.ht/~romi/offu/commits/front.svg
[license]: https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat
