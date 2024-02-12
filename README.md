# Offu

A library to parse and edit [Unified Font Objects][UFO] v3 written in Zig.

[![][builds.sr.ht]](https://builds.sr.ht/~romi/offu/commits/front?)
[![][license]](https://git.sr.ht/~romi/offu/tree/front/item/LICENSE)


The goal is to have a library to rely on for tools such as a
non-exporting glyphs remover, a UFO normalizer, running Q.A. tests, or
parsing the necessary information to build fonts, etc.

There are still some rough edges (only partial reading is supported so far!).  
This library follows Zig master releases, a nix flake helps with that.


## Features

No Python.


## Installation

```sh
; zig fetch --save git+https://git.sr.ht/~romi/offu#front
```

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const offu = b.dependency("offu", .{
        .target = target,
        .optimize = optimize,
    }).module("offu");

    const exe = b.addExecutable(.{
        .name = "my-project",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("offu", offu);
}
```


## Examples

Browse the `examples` directory.

```sh
; zig build examples
```


## Docs

API: https://sansfontieres.com/docs/offu

[UFO]: https://unifiedfontobject.org/versions/ufo3/
[builds.sr.ht]: https://builds.sr.ht/~romi/offu/commits/front.svg
[license]: https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat
