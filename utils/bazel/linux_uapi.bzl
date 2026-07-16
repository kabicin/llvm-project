# This file is licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

"""bzlmod extension for making Linux Kernel UAPI headers available in Bazel."""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

_SYSTEM_HEADERS_PATH_ENV_VAR = "LINUX_UAPI_INCLUDE_DIR"

_HERMETIC_BUILD = """\
load("@rules_foreign_cc//foreign_cc:defs.bzl", "make")
load("@rules_cc//cc:defs.bzl", "cc_library")

filegroup(
    name = "srcs",
    srcs = glob(["linux_srcs/**"]),
)

make(
    name = "uapi_gen",
    args = ["INSTALL_HDR_PATH=$$INSTALLDIR$$", "-j`nproc`"],
    lib_source = ":srcs",
    out_headers_only = True,
    targets = ["headers_install"],
)

genrule(
  name = "list_headers",
  srcs = [":uapi_gen"],
  outs = ["list.txt"],
  cmd = "ls -Rh $(SRCS) > $@"
)

cc_library(
    name = "linux_uapi_headers",
    textual_hdrs = [":uapi_gen"],
    includes = ["uapi_gen/include"],
    visibility = ["//visibility:public"],
)
"""

def _linux_uapi_hermetic_setup(name):
    """Sets up a repository of UAPI headers directly from Linux sources."""
    git_repository(
        name = name,
        remote = "https://github.com/torvalds/linux.git",
        commit = "028ef9c96e96197026887c0f092424679298aae8",  # v7.0
        # Pull a minimal set of directories to avoid a several GiB download.
        sparse_checkout_patterns = [
            "arch/**",
            "include/uapi/**",
            "Makefile",
            "scripts/**",
        ],
        build_file_content = _HERMETIC_BUILD,
        # Move everything into a subfolder. Similar to http_archive's `add_prefix`.
        patch_cmds = [
            "mkdir linux_srcs",
            "find . -maxdepth 1 ! -name BUILD.bazel -exec mv {} linux_srcs \\;",
        ],
    )

_SYSTEM_BUILD = """\
load("@rules_cc//cc:defs.bzl", "cc_library")

filegroup(
    name = "srcs",
    srcs = glob(["include/**"]),
)

cc_library(
    name = "linux_uapi_headers",
    textual_hdrs = [":srcs"],
    includes = ["include"],
    visibility = ["//visibility:public"],
)
"""

def _linux_uapi_system_setup_impl(repository_ctx):
    """Sets up a repository of UAPI headers from a system directory."""
    repository_ctx.symlink(repository_ctx.attr.include_dir, "include")
    repository_ctx.file("BUILD.bazel", _SYSTEM_BUILD)

_linux_uapi_system_setup = repository_rule(
    implementation = _linux_uapi_system_setup_impl,
    attrs = {
        "include_dir": attr.string(mandatory = True),
    },
)

def _linux_uapi_extension_impl(module_ctx):
    include_dir = module_ctx.os.environ.get(_SYSTEM_HEADERS_PATH_ENV_VAR, "")
    if include_dir:
        _linux_uapi_system_setup(
            name = "linux_uapi",
            include_dir = include_dir,
        )
    else:
        _linux_uapi_hermetic_setup(name = "linux_uapi")

linux_uapi_extension = module_extension(
    implementation = _linux_uapi_extension_impl,
    environ = [_SYSTEM_HEADERS_PATH_ENV_VAR],
)
