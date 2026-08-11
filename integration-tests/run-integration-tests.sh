#!/bin/bash

echo integration-tests/execution-fail...

TEST_PROCESSES=1 CI=1 dotnet run integration-tests/execution-fail | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/execution-fail unexpectedly succeeded

    exit 1
fi

if [ ! -f actual-output ] ; then
    echo integration-tests/execution-fail produced no output

    exit 1
fi

if ! diff integration-tests/execution-fail/expected-output actual-output ; then
    echo integration-tests/execution-fail output did not match expected output

    exit 1
fi

echo integration-tests/execution-fail: PASS


TEST_PROCESSES=1 CI=1 dotnet run integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/execution-pass unexpectedly succeeded

    exit 1
fi

if [ ! -f actual-output ] ; then
    echo integration-tests/execution-pass produced no output

    exit 1
fi

if ! diff integration-tests/execution-pass/expected-output actual-output ; then
    echo integration-tests/execution-pass output did not match expected output

    exit 1
fi

echo integration-tests/execution-pass: PASS


echo integration-tests/runtime-dll-override-valid...

# The --runtime-dll override should be transparent when pointed at the same
# runtime that CI mode would have discovered itself: hello-world still passes.
RUNTIME_DLL="$(pwd)/bin/Debug/net10.0/ghul-runtime.dll"

if [ ! -f "$RUNTIME_DLL" ]; then
    echo "expected runtime DLL not found at $RUNTIME_DLL"
    exit 1
fi

TEST_PROCESSES=1 CI=1 dotnet run -- --runtime-dll "$RUNTIME_DLL" integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/runtime-dll-override-valid unexpectedly failed

    exit 1
fi

if ! diff integration-tests/execution-pass/expected-output actual-output ; then
    echo integration-tests/runtime-dll-override-valid output did not match expected output

    exit 1
fi

echo integration-tests/runtime-dll-override-valid: PASS


echo integration-tests/runtime-dll-override-missing...

# A missing runtime DLL must fail fast with a clear message, not silently fall
# back to default discovery.
TEST_PROCESSES=1 CI=1 dotnet run -- --runtime-dll /tmp/ghul-test-no-such-runtime.dll integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/runtime-dll-override-missing did not exit 1

    exit 1
fi

if ! grep -q "runtime DLL not found" actual-output ; then
    echo integration-tests/runtime-dll-override-missing did not report missing-DLL error

    exit 1
fi

echo integration-tests/runtime-dll-override-missing: PASS


echo integration-tests/dotnet-build...

TEST_PROCESSES=1 CI=1 dotnet run -- --use-dotnet-build --compiler "dotnet ghul-compiler" integration-tests/dotnet-build | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/dotnet-build unexpectedly failed

    exit 1
fi

if ! diff integration-tests/dotnet-build/expected-output actual-output ; then
    echo integration-tests/dotnet-build output did not match expected output

    exit 1
fi

echo integration-tests/dotnet-build: PASS


echo integration-tests/compiler-override-honoured...

# The chosen compiler has to reach the build itself, not just be reported: a
# command that is not a compiler must fail the build it was handed to.
TEST_PROCESSES=1 CI=1 dotnet run -- --use-dotnet-build --compiler /bin/false integration-tests/dotnet-build | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/compiler-override-honoured did not exit 1

    exit 1
fi

if ! grep -q "unexpected build failure" actual-output ; then
    echo integration-tests/compiler-override-honoured did not fail the build

    exit 1
fi

echo integration-tests/compiler-override-honoured: PASS


echo integration-tests/compiler-override-missing...

# A missing compiler must fail fast with a clear message, not silently fall back
# to whatever the project resolves for itself.
TEST_PROCESSES=1 CI=1 dotnet run -- --use-dotnet-build --compiler /tmp/ghul-test-no-such-compiler integration-tests/dotnet-build | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/compiler-override-missing did not exit 1

    exit 1
fi

if ! grep -q "compiler not found" actual-output ; then
    echo integration-tests/compiler-override-missing did not report missing-compiler error

    exit 1
fi

echo integration-tests/compiler-override-missing: PASS


echo integration-tests/compiler-override-wrong-mode...

# --compiler only means anything for a `dotnet build` run, so asking for it
# elsewhere is an error rather than a silently ignored flag.
TEST_PROCESSES=1 CI=1 dotnet run -- --compiler /bin/false integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/compiler-override-wrong-mode did not exit 1

    exit 1
fi

if ! grep -q "only be set for --use-dotnet-build" actual-output ; then
    echo integration-tests/compiler-override-wrong-mode did not report the mode error

    exit 1
fi

echo integration-tests/compiler-override-wrong-mode: PASS

echo integration-tests/il-expected...

# A test carrying il.expected has the emitted assembly disassembled and
# compared, so this covers the whole path: running ildasm, dropping the lines
# that describe the run rather than the assembly, and diffing what is left.
TEST_PROCESSES=1 CI=1 dotnet run integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/il-expected unexpectedly failed

    exit 1
fi

if ! diff integration-tests/il-expected/expected-output actual-output ; then
    echo integration-tests/il-expected output did not match expected output

    exit 1
fi

echo integration-tests/il-expected: PASS


exit 0
