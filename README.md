# ghūl compiler integration test runner

[![CI/CD](https://img.shields.io/github/actions/workflow/status/degory/ghul-test/cicd.yml?branch=main)](https://github.com/degory/ghul-test/actions?query=workflow%3ACICD+branch%3Amain)
[![NuGet version (ghul.test)](https://img.shields.io/nuget/v/ghul.test.svg)](https://www.nuget.org/packages/ghul.test/)
[![Release](https://img.shields.io/github/v/release/degory/ghul-test?label=release)](https://github.com/degory/ghul-test/releases)
[![Release Date](https://img.shields.io/github/release-date/degory/ghul-test)](https://github.com/degory/ghul-test/releases)
[![Issues](https://img.shields.io/github/issues/degory/ghul-test)](https://github.com/degory/ghul-test/issues) 
[![License](https://img.shields.io/github/license/degory/ghul-test)](https://github.com/degory/ghul-test/blob/main/LICENSE)
[![ghūl](https://img.shields.io/badge/gh%C5%ABl-100%25!-information)](https://ghul.dev)

This is a very simple snapshot based test runner which is used by the [ghūl programming language](https://ghul.dev) [compiler](https://github.com/degory/ghul) [integration tests](https://github.com/degory/ghul/tree/master/integration-tests). It compares test expectations, in the form of snapshot text files, against the actual outputs of the compiler and test executables and flags any differences.

## Test Folder Structure

A test directory must contain at least two things:

- **One or more `.ghul` source files** – the sources to compile.
- A `ghulflags` file – flags passed directly to the compiler when building the test.

Any directory containing a `ghulflags` file is treated as a test. Subdirectories without this file are ignored by the queue logic.

Optional expectation and configuration files may also be present:

| File | Purpose |
| --- | --- |
| `fail.expected` | If present, the build is expected to fail. Its mere presence enables this behaviour; the file contents are ignored. |
| `err.expected` | Expected compiler error output. Actual errors are extracted from `compiler.out`, sorted, and diffed against this file. |
| `warn.expected` | Expected compiler warning output. Warnings undergo the same grep and sort process as errors. |
| `run.expected` | Expected stdout from running the compiled binary. |
| `il.expected` | Expected IL disassembly output (from the `il.out` file). |
| `ghulflags` | Mandatory file containing additional command line flags for the compiler. |
| `disabled*` | Any file beginning with `disabled` causes the test to be skipped. |
| `tags` | Zero or more whitespace-separated tag names (spaces or newlines), used to select a subset of tests with `--tag` / `--not-tag`. A test with no `tags` file has no tags. |

A basic “hello world” example can be found in the `integration-tests` folder of this repository.

## Expectation Comparison Workflow

1. The runner invokes the compiler using the arguments from `ghulflags` and the test’s `.ghul` sources. Compiler stdout/stderr is written to `compiler.out`.
2. `grep` extracts error and warning lines from `compiler.out` into `err.grep` and `warn.grep` respectively.
3. These files are sorted with `sort` (with `LC_COLLATE` set to `C` for stable output) into `err.sort` and `warn.sort`.
4. `diff` compares `err.sort` to `err.expected` and `warn.sort` to `warn.expected`. Whitespace differences are ignored and carriage returns are stripped.
5. If compilation succeeded, `ghul-runtime.dll` is symlinked into the test directory and the binary is executed via `dotnet`. Output is captured in `run.out` and compared to `run.expected`.
6. If an `il.expected` file exists, `diff` is run against the generated `il.out` file as well.

Any mismatches cause a failure report containing a unified diff of the actual versus expected output.

## Command Line Usage

```text
ghul-test [--use-dotnet-build] [--compiler <command>] [--runtime-dll <path>] [--tag <name>]... [--not-tag <name>]... <test-folder> [...]
```

- `--use-dotnet-build` – expects each test folder to be an MSBuild project. For ghūl projects the file should end with `.ghulproj`. The runner builds the project with `dotnet build` instead of invoking the compiler directly.
- `--compiler <command>` – the command each test project is built with, supplied to MSBuild as the `GhulCompiler` property. A command containing no spaces must name an existing file; anything with arguments in it, such as `dotnet /path/to/ghul.dll`, is passed through as written. Takes precedence over the `GHUL_TEST_COMPILER` environment variable and over the publish directory described below. Only meaningful under `--use-dotnet-build` — the other modes invoke the compiler directly and resolve it themselves — so supplying it elsewhere is an error.
- `--runtime-dll <path>` – use the supplied `ghul-runtime.dll` for compiled test binaries instead of the version that ships with `ghul-test`. The path must point to an existing file. Takes precedence over the `GHUL_RUNTIME_DLL` environment variable. Has no effect under `--use-dotnet-build`, which resolves the runtime via the test project's own `PackageReference`.
- `--tag <name>` – restrict discovery to tests whose `tags` file contains at least one of the given names. Repeatable; the requested tags are matched as a union (a test runs if it carries *any* of them), not an intersection. A test with no `tags` file is excluded whenever any `--tag` is given. Omit entirely to run every discovered test regardless of tags, which is unchanged from before this flag existed.
- `--not-tag <name>` – exclude tests whose `tags` file contains any of the given names. Repeatable, and matched as a union in the same way. A test with no `tags` file is never excluded by it. Exclusion is applied before inclusion and wins over it, so a test carrying both a requested and an excluded tag is skipped. Combines with `--tag`: `--tag generics --not-tag async` runs the generics tests that are not also async ones.
- `<test-folder>` – one or more directories containing tests. Each is recursively searched for subdirectories with a `ghulflags` file if not using `--use-dotnet-build`.

Environment variables influence behaviour:

- `HOST` and `TARGET` – specify the CLI used to run the compiler and the compiled binary (default `dotnet`).
- `CI` – when set to `1` or `true`, enables CI mode. In this mode `ghul-runtime.dll` is taken from the test runner's own location unless overridden by `--runtime-dll` / `GHUL_RUNTIME_DLL`.
- `GHUL_RUNTIME_DLL` – path to a `ghul-runtime.dll` to use for compiled test binaries, overriding the version that ships with `ghul-test`. Equivalent to passing `--runtime-dll`; the CLI flag wins if both are set.
- `GHUL_TEST_COMPILER` – command each test project is built with under `--use-dotnet-build`. Equivalent to passing `--compiler`; the CLI flag wins if both are set.
- `TEST_PROCESSES` – number of worker processes to use. If unset, a value derived from CPU count is used.
- `GHUL_TEST_KEEP_ARTIFACTS` – when set, keep every test's build and run artifacts instead of deleting them on success. A passing test normally cleans up after itself, so a green run leaves only the failures behind; set this to inspect what was actually built — to audit every emitted assembly, or to look at a test that passes but is suspected of passing for the wrong reason.

The runner prints progress for each test and a final summary indicating total, enabled, passed and failed counts.

## Runtime Library Handling

When the compiler is invoked directly (the default and CI modes), the produced executable expects to find `ghul-runtime.dll` beside it. The runner therefore creates a symbolic link in the test directory pointing to the runtime library. This link is not needed when `--use-dotnet-build` is used. After the test completes successfully, the link is deleted during cleanup.

By default the runtime DLL is sourced from the published compiler's directory (LOCAL mode) or the test runner's own install directory (CI mode). When the integration tests need to run against a runtime version other than the one `ghul-test` itself was packaged with — for example, when CI builds a compiler that depends on a newer `ghul.runtime` than the pinned `ghul.test` ships with — pass `--runtime-dll <path>` or set `GHUL_RUNTIME_DLL` to override the discovered location with an explicit DLL path.

## Compiler Selection Under `--use-dotnet-build`

Invoked directly, the runner knows exactly which compiler it is testing — the published one it found or was given. A `dotnet build` run does not: the project decides, and a project that leaves the decision to the .NET local tool manifest will build just as quietly against a published compiler as against the one being tested. A suite meant to exercise a compiler change can therefore pass without ever running it.

So the runner chooses, in this order:

1. `--compiler` / `GHUL_TEST_COMPILER`, if supplied.
2. The compiler in the nearest `publish` directory at or above the working directory, if there is one. This is where a compiler being tested is normally published to, so it is preferred over the tool manifest.
3. Otherwise nothing: the property is left alone and each project resolves the compiler for itself.

Whichever applies is reported before the run starts. The choice is passed to MSBuild as the `GhulCompiler` property, through the environment, so a project that assigns `GhulCompiler` unconditionally in its own `PropertyGroup` overrides it — the `.ghulproj` files of a suite intended to test a compiler should leave the property unset.

## MSBuild Projects

This runner does **not** execute arbitrary MSBuild projects. It either drives the compiler directly on `.ghul` source files or, when `--use-dotnet-build` is supplied, assumes the folder already contains a valid MSBuild project (for ghūl projects this means a `*.ghulproj` file). Only a small set of standard .NET assemblies is referenced so complex projects are out of scope.

## Dependencies

The runner relies on several standard Unix utilities being available in the environment: `grep`, `sort`, `diff` and `ln`. A .NET 10 SDK installation is required; mono is not supported.

## Writing New Tests

This repository includes helper scripts under `./scripts`:

- `create.sh` – create a new test directory from the built-in template.
- `capture.sh` – update expectation files after running a test.

1. Run `./scripts/create.sh` and provide the new test name.
2. Edit the generated `.ghul` sources and `ghulflags` as required.
3. Execute `ghul-test <path-to-test>` (expect it to fail initially). The runner produces `.out` files with the actual output.
4. Run `./scripts/capture.sh <path-to-test>` to copy the `.out` files over the corresponding `*.expected` files.
5. Re-run `ghul-test` and verify the test now passes.
6. Commit the test directory along with the expectations.

Refer to the [ghūl compiler integration tests](https://github.com/degory/ghul/tree/main/integration-tests) for many real‑world examples of this structure.

