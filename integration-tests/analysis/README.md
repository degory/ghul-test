# Analysis mode integration tests

These tests run the ghūl compiler in **analysis mode** (`-A`): the test runner spawns the compiler, sends protocol commands (EDIT, optionally COMPILE) on stdin, and compares the compiler’s stdout to snapshot files.

The runner uses the same **“under test”** mode as the compile tests (`--v3 --test-run` plus `-A`). The compiler then uses its default reference assemblies (sdk refs and `install_folder`/ghul-runtime.dll), so no response file or `-a` args are required.

## Diagnostics: store state, not raw stream

The runner models the **client’s diagnostics store**: a set of diagnostic messages per path/URI. When the compiler sends a **DIAGNOSTICS** section:

- A **path-only line** (no tabs) clears diagnostics for that path.
- **Tab-delimited lines** (path, start_line, start_column, end_line, end_column, severity, message) define the full set of diagnostics for that path for this section.

Each DIAGNOSTICS section **replaces** the store for every path that appears in it (path-only clears; tab-delimited lines set that path’s list to exactly those entries). So a second DIAGNOSTICS section for the same URI replaces the first; diagnostics do not accumulate across sections.

The snapshot does **not** record the exact sequence of DIAGNOSTICS sections. Instead it asserts the **final store state** in a block `DIAGNOSTICS STORE`: for each path (sorted), either `(none)` or a sorted list of entries in the form `start_line,start_col..end_line,end_col severity message`. So tests are stable regardless of how many times the compiler sends DIAGNOSTICS or in what order.

## Requirements

- Run from a directory that contains a published compiler (for LOCAL) or use `CI=1` (for CI mode), same as for compile tests.

## Running

From the repo root (e.g. ghul or ghul-test):

```sh
dotnet ghul-test integration-tests
```

Analysis tests under `integration-tests/analysis/` are discovered and run together with compile/run tests.

## Capturing expectations

After changing compiler behaviour or adding a test:

1. Run the test (it may fail with a diff).
2. Copy `analysis.out` to `analysis.expected` in the test directory (or use your project’s “capture” task if available).

## Test layout

Each subdirectory (e.g. `edit-only/`) must have:

- At least one `*.ghul` source file.
- **`analysis.ghulflags`** or **`ghulflags`**: flags passed to the compiler. The runner adds `-A` and test-run args.

Optional:

- **`analysis.scenarios`**: after EDIT, run extra protocol commands (e.g. EDIT_AGAIN, HOVER, DEFINITION). Blocks are separated by a blank line; first line of each block is the command name, following lines are payload (path, line, column for HOVER/DEFINITION; all 1-based). **EDIT_AGAIN** takes two lines: the path to send in the edit (same path as the initial edit, e.g. `test.ghul`), and the file name to read content from (e.g. `test-step2.ghul`). When EDIT_AGAIN is present, the initial EDIT sends only that path so the second edit replaces that file’s content. Example:
  ```
  EDIT_AGAIN
  test.ghul
  test-step2.ghul

  HOVER
  test.ghul
  2
  8
  ```
- **`analysis.expected`**: snapshot of expected protocol output. If missing, the test fails and you can capture from `analysis.out`.

## Tests included

- **edit-only**: EDIT only; no errors; store shows `(none)` for each path.
- **hover**: EDIT then two HOVER requests (on `Std` and on a local variable); checks HOVER responses.
- **definition**: EDIT then DEFINITION request; checks DEFINITION response round-trip.
- **diagnostics-syntax**: Source with a **syntax** error (incomplete `if`); asserts the diagnostics store contains one error from the parser (e.g. “expected … but found si”).
- **diagnostics-semantic**: Source with a **semantic** error (undefined symbol `_runtime_path`); asserts the store contains one error from semantic analysis (“symbol not found: _runtime_path”).
- **diagnostics-clear**: Initial EDIT has one file with a semantic error; EDIT_AGAIN sends the same path with content from `test-step2.ghul` that fixes the error. Asserts the store ends with `(none)` for that file.
- **diagnostics-remain**: Initial EDIT has one file with a semantic error; EDIT_AGAIN sends the same path with content from `test-step2.ghul` that does not fix the error (e.g. adds a comment after the error). Asserts the store still contains the error(s).
