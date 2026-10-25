"""Expose OpenMP build inputs without leaking its CcInfo to consumers."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _linking_only_impl(ctx):
    return [CcInfo(linking_context = ctx.attr.dep[CcInfo].linking_context)]

linking_only = rule(
    implementation = _linking_only_impl,
    attrs = {"dep": attr.label(mandatory = True, providers = [CcInfo])},
)

def _openmp_header_impl(ctx):
    headers = [
        header
        for header in ctx.attr.dep[CcInfo].compilation_context.headers.to_list()
        if header.basename == "omp.h"
    ]
    if len(headers) != 1:
        fail("Expected one OpenMP header, got %s" % headers)
    return [DefaultInfo(files = depset(headers))]

openmp_header = rule(
    implementation = _openmp_header_impl,
    attrs = {"dep": attr.label(mandatory = True, providers = [CcInfo])},
)

def _static_archive_impl(ctx):
    archives = []
    for linker_input in ctx.attr.dep[CcInfo].linking_context.linker_inputs.to_list():
        for library in linker_input.libraries:
            archive = library.pic_static_library or library.static_library
            if archive:
                archives.append(archive)
    if len(archives) != 1:
        fail("Expected one OpenMP archive, got %s" % archives)
    return [DefaultInfo(files = depset(archives))]

static_archive = rule(
    implementation = _static_archive_impl,
    attrs = {"dep": attr.label(mandatory = True, providers = [CcInfo])},
)
