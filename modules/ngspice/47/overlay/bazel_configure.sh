#!/usr/bin/env bash
set -euo pipefail

# Detect the actual toolchain compiler: --compiler can be unset even with Clang.
# GCC uses its own OpenMP ABI/runtime. Clang uses the BCR LLVM runtime archive,
# bypassing the driver flag that would otherwise look for a host libomp.
if [[ -n "${NGSPICE_OPENMP_ARCHIVE:-}" ]]; then
  macros="$($CC ${CPPFLAGS:-} ${CFLAGS:-} -dM -E -x c /dev/null)"
  if [[ "$macros" == *'__clang__'* ]]; then
    export CPPFLAGS="${CPPFLAGS:-} -I${NGSPICE_OPENMP_HEADER%/*}"
    # Keep this a single token: libtool otherwise duplicates the bare -fopenmp.
    export CFLAGS="${CFLAGS:-} -Xclang=-fopenmp"
    # A raw archive in LIBS is nested inside upstream's convenience archives by
    # libtool. A unique -l name preserves normal static link semantics and cannot
    # accidentally select a shared OpenMP library from the host.
    mkdir -p bazel-openmp
    ln -s "$NGSPICE_OPENMP_ARCHIVE" bazel-openmp/libngspice_openmp.a
    runtime_libs="-L$PWD/bazel-openmp -lngspice_openmp"
    if [[ "$macros" == *'__APPLE__'* ]]; then
      export LIBS="$runtime_libs -lc++ ${LIBS:-}"
    else
      export LIBS="$runtime_libs -lstdc++ -lpthread -ldl ${LIBS:-}"
    fi
  fi
fi

exec bash "$(dirname "$0")/configure" "$@"
