# ngspice

This module builds the ngspice 47 release with its upstream Autoconf/Make
build. It provides a static library exposing ngspice's simulator API, a command-line
simulator, and the runtime code-model libraries needed by XSPICE. XSPICE and OpenMP are
enabled by default and can be disabled independently.

## Usage

```starlark
bazel_dep(name = "ngspice", version = "47")
```

Public targets:

| Target | Purpose |
| --- | --- |
| `@ngspice//:ngspice` | Static C API library, with `<ngspice/sharedspice.h>` |
| `@ngspice//:ngspice_bin` | Runnable headless command-line simulator |
| `@ngspice//:runtime` | Installation tree containing XSPICE `.cm` libraries and scripts |

```sh
bazel run @ngspice//:ngspice_bin -- -b circuit.cir
bazel build @ngspice --@ngspice//:openmp=false
bazel build @ngspice --@ngspice//:xspice=false
```

The CLI launcher resolves its runtime files using Bazel runfiles and creates
a temporary `spinit` that loads the matching code models. It works from an
arbitrary current directory. User `.spiceinit` files retain ngspice's normal
behavior. `-n` deliberately disables initialization, including code-model
loading, as in upstream ngspice.

For embedding, depend on `@ngspice//:ngspice` and add `@ngspice//:runtime` to
`data` if using XSPICE. Resolve that tree with your application's runfiles
library, initialize ngspice, and issue `codemodel "<tree>/lib/ngspice/analog.cm"`
and the equivalent commands for the needed models. The seven bundled models
are `spice2poly`, `analog`, `digital`, `xtradev`, `xtraevt`, `table`, and `tlines`.
The external consumer in `47/overlay/bazel_test` demonstrates initialization,
model loading, and numerical validation. Set `SPICE_SCRIPTS` before initializing
the library to control which system startup scripts it reads. In release 47,
the pre-initialization `ngSpice_nospinit` API crashes; the example uses the
environment override instead.
The library exports the `XSPICE` preprocessor definition when enabled, exposing
the event-node API in `sharedspice.h` to dependent C/C++ targets.

## Build choices

The initial platform scope is native Linux and macOS builds. GCC uses the
OpenMP runtime supplied by its C toolchain. Clang, including Apple Clang,
uses the `openmp` module from BCR; no Homebrew paths or host `libomp` are required.
The API library links statically so the final executable resolves a single
OpenMP runtime, including when the application itself depends on `@openmp`.
Embedding a private static OpenMP runtime inside a shared ngspice library
causes LLVM to abort when another OpenMP runtime is already initialized.
Only runtime linking information is propagated; LLVM's headers stay private
unless a consumer explicitly depends on `@openmp`.
The configure wrapper and rules_cc compiler selectors use the actual compiler
rather than assuming that Bazel's `--compiler` flag is set.
OpenMP parallelizes ngspice's BSIM3 and BSIM4 device evaluation. Select the
thread count with ngspice's `set num_threads=<n>` command.

The module uses the generated parsers and build files shipped in the release
archive, so flex, bison, autoconf, and automake are not needed. Make is provided
by `rules_foreign_cc`. X11, readline, editline, FFTW, optional audio libraries,
CIDER, and OSDI are disabled to avoid undeclared host dependencies. Ngspice's
bundled KLU solver is retained. Cross-compilation and Windows are outside the
initial tested scope.

The small `codemodel-quoted-paths.patch` applies ngspice's existing unquoting
function to `codemodel` arguments, allowing runtime paths containing spaces.
`disabled-xspice.patch` fixes an upstream option switch that references an
XSPICE-only constant when XSPICE is disabled. `configure-portability.patch`
fixes the macOS build-date command and a stray shell comma in the release's
Bison probe. The build timestamp is pinned to the release archive.
The build overlay follows upstream's configure options rather than maintaining
a separate list of the simulator's C sources.

## Validation

The consumer tests exercise the public API library and CLI, check feature
availability, verify a voltage divider, load all seven code-model libraries,
simulate analog and digital XSPICE circuits, and compare BSIM3/BSIM4 results
at different thread counts. Tests also exercise the XSPICE event API and CLI
script lookup, including runtime and temporary paths with spaces. BCR presubmit
covers Linux and macOS on Bazel 8 and 9, independently exercises both feature
switches with GCC on Linux, and tests Linux Clang's OpenMP runtime linking.
A GCC consumer uses its own OpenMP API alongside ngspice to catch header or
runtime leakage from LLVM OpenMP. A Clang consumer runs parallel work before
and after an ngspice BSIM simulation to catch duplicate runtime initialization.

To materialize the consumer tests from an unpublished registry checkout, run
the setup helper from the BCR root and follow the printed test instructions:

```sh
bazel run //tools:setup_presubmit_repos -- --module ngspice@47
```

Registry validation:

```sh
bazel run //tools:update_integrity -- ngspice --version=47
bazel run //tools:bcr_validation -- --check=ngspice@47
```
