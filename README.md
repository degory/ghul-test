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
ghul-test [--use-dotnet-build] <test-folder> [...]
```

- `--use-dotnet-build` – expects each test folder to be an MSBuild project. For ghūl projects the file should end with `.ghulproj`. The runner builds the project with `dotnet build` instead of invoking the compiler directly.
- `<test-folder>` – one or more directories containing tests. Each is recursively searched for subdirectories with a `ghulflags` file if not using `--use-dotnet-build`.

Environment variables influence behaviour:

- `HOST` and `TARGET` – specify the CLI used to run the compiler and the compiled binary (default `dotnet`).
- `CI` – when set to `1` or `true`, enables CI mode. In this mode `ghul-runtime.dll` is taken from the test runner’s own location.
- `TEST_PROCESSES` – number of worker processes to use. If unset, a value derived from CPU count is used.

The runner prints progress for each test and a final summary indicating total, enabled, passed and failed counts.

## Runtime Library Handling

When the compiler is invoked directly (the default and CI modes), the produced executable expects to find `ghul-runtime.dll` beside it. The runner therefore creates a symbolic link in the test directory pointing to the runtime library. This link is not needed when `--use-dotnet-build` is used. After the test completes successfully, the link is deleted during cleanup.

## MSBuild Projects

This runner does **not** execute arbitrary MSBuild projects. It either drives the compiler directly on `.ghul` source files or, when `--use-dotnet-build` is supplied, assumes the folder already contains a valid MSBuild project (for ghūl projects this means a `*.ghulproj` file). Only a small set of standard .NET assemblies is referenced so complex projects are out of scope.

## Dependencies

The runner relies on several standard Unix utilities being available in the environment: `grep`, `sort`, `diff` and `ln`. A .NET 8 SDK installation is required; mono is not supported.

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

