# This file is licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

"""bzlmod extension for making Linux Kernel UAPI headers available in Bazel."""

_SYSTEM_HEADERS_PATH_ENV_VAR = "LINUX_UAPI_INCLUDE_DIR"

_ERROR_MESSAGE_BZL = """\
def error_message(name, message):
    fail(message)
"""

_ERROR_BUILD = """\
load(":error_message.bzl", "error_message")

error_message(
    name = "linux_uapi_headers",
    message = "System linux UAPI headers not found. Pass --repo_env={var_name}=/path/to/your/linux/include to bazel build."
)
""".format(var_name = _SYSTEM_HEADERS_PATH_ENV_VAR)

def _linux_uapi_unavailable_setup_impl(repository_ctx):
    """Sets a repo that errors when used."""
    repository_ctx.file("error_message.bzl", _ERROR_MESSAGE_BZL)
    repository_ctx.file("BUILD.bazel", _ERROR_BUILD)

_linux_uapi_unavailable_setup = repository_rule(
    implementation = _linux_uapi_unavailable_setup_impl,
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
        _linux_uapi_unavailable_setup(name = "linux_uapi")

linux_uapi_extension = module_extension(
    implementation = _linux_uapi_extension_impl,
    environ = [_SYSTEM_HEADERS_PATH_ENV_VAR],
)
