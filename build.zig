const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libxml2_dep = b.dependency(
        "libxml2",
        .{
            .optimize = .ReleaseFast,
            .iconv = false,
            .lzma = false,
            .zlib = false,
        },
    );

    const offu_mod = b.addModule(
        "offu",
        .{
            .root_source_file = .{ .path = "src/offu.zig" },
        },
    );
    offu_mod.linkLibrary(libxml2_dep.artifact("xml2"));

    const offu = b.addObject(.{
        .name = "offu",
        .root_source_file = .{ .path = "src/offu.zig" },
        .target = target,
        .optimize = optimize,
    });
    const docs_path = offu.getEmittedDocs();
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_path,
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.linkLibrary(libxml2_dep.artifact("xml2"));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
