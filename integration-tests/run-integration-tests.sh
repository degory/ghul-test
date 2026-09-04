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

echo integration-tests/ildasm-override-missing...

# A disassembler named explicitly but absent must fail fast with one clear
# message, not fall back to discovery and quietly use something else.
TEST_PROCESSES=1 CI=1 dotnet run -- --ildasm /tmp/ghul-test-no-such-ildasm integration-tests/execution-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/ildasm-override-missing did not exit 1

    exit 1
fi

if ! grep -q "disassembler not found" actual-output ; then
    echo integration-tests/ildasm-override-missing did not report the missing disassembler

    exit 1
fi

echo integration-tests/ildasm-override-missing: PASS

echo integration-tests/il-item-missing...

# An il.item the assembly does not contain has to be reported. The
# disassembler says nothing about one and exits zero, writing only the
# assembly preamble, so a snapshot captured from it would assert nothing about
# the construct it names and pass for good.
TEST_PROCESSES=1 CI=1 dotnet run integration-tests/il-item-missing | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/il-item-missing did not exit 1

    exit 1
fi

if ! grep -q "which the emitted assembly does not contain" actual-output ; then
    echo integration-tests/il-item-missing did not report the missing item

    exit 1
fi

echo integration-tests/il-item-missing: PASS

echo integration-tests/il-item-property...

# An il.item naming a field or property is a documented use, and the enclosing
# class is written out around it, so the check that the item was found has to
# accept a member directive rather than only a method.
TEST_PROCESSES=1 CI=1 dotnet run integration-tests/il-item-property | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/il-item-property unexpectedly failed

    exit 1
fi

if ! diff integration-tests/il-item-property/expected-output actual-output ; then
    echo integration-tests/il-item-property output did not match expected output

    exit 1
fi

echo integration-tests/il-item-property: PASS


echo integration-tests/il-item-typo...

# A member that does not exist on a type that does. The enclosing class is
# written out either way, so this is the case a check for the class alone
# would wave through.
TEST_PROCESSES=1 CI=1 dotnet run integration-tests/il-item-typo | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/il-item-typo did not exit 1

    exit 1
fi

if ! grep -q "which the emitted assembly does not contain" actual-output ; then
    echo integration-tests/il-item-typo did not report the missing member

    exit 1
fi

echo integration-tests/il-item-typo: PASS

echo integration-tests/ildasm-override-relative...

# A relative --ildasm path is checked against this directory and then run from
# another: every test is launched with its own folder as the working
# directory. Unresolved, it would name a different file there, or nothing.
TEST_PROCESSES=1 CI=1 dotnet run -- --ildasm ./bin/Debug/net10.0/runtimes/linux-x64/native/ildasm integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/ildasm-override-relative unexpectedly failed

    exit 1
fi

if ! diff integration-tests/il-expected/expected-output actual-output ; then
    echo integration-tests/ildasm-override-relative output did not match expected output

    exit 1
fi

echo integration-tests/ildasm-override-relative: PASS

echo integration-tests/ildasm-env-missing...

# GHUL_TEST_ILDASM is documented as equivalent to --ildasm, so a path that
# does not exist has to fail the same way rather than being ignored in favour
# of the shipped copy - which would silently run something other than what was
# asked for.
TEST_PROCESSES=1 CI=1 GHUL_TEST_ILDASM=/tmp/ghul-test-no-such-ildasm dotnet run integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/ildasm-env-missing did not exit 1

    exit 1
fi

if ! grep -q "disassembler not found" actual-output ; then
    echo integration-tests/ildasm-env-missing did not report the missing disassembler

    exit 1
fi

echo integration-tests/ildasm-env-missing: PASS

echo integration-tests/format-pass...

TEST_PROCESSES=1 CI=1 dotnet run integration-tests/format-pass | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/format-pass unexpectedly failed

    exit 1
fi

if ! diff integration-tests/format-pass/expected-output actual-output ; then
    echo integration-tests/format-pass output did not match expected output

    exit 1
fi

echo integration-tests/format-pass: PASS


echo integration-tests/format-fail...

TEST_PROCESSES=1 CI=1 dotnet run integration-tests/format-fail | tee actual-output

if [ "${PIPESTATUS[0]}" != "1" ]; then
    echo integration-tests/format-fail unexpectedly succeeded

    exit 1
fi

if ! diff integration-tests/format-fail/expected-output actual-output ; then
    echo integration-tests/format-fail output did not match expected output

    exit 1
fi

echo integration-tests/format-fail: PASS


echo integration-tests/ildasm-not-executable...

# A NuGet package carries no Unix permissions, so the disassembler shipped
# inside the tool arrives without its execute bit and launching it fails with
# "Permission denied" naming a path that exists. Only reproducible against the
# packaged layout, which is what every consumer installs, so the built tool is
# run directly here with the bit cleared.
chmod -x bin/Debug/net10.0/runtimes/linux-x64/native/ildasm

rm -f integration-tests/il-expected/hello-world/il.out

TEST_PROCESSES=1 CI=1 dotnet bin/Debug/net10.0/ghul-test.dll integration-tests/il-expected | tee actual-output

if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo integration-tests/ildasm-not-executable unexpectedly failed

    exit 1
fi

if [ ! -x bin/Debug/net10.0/runtimes/linux-x64/native/ildasm ]; then
    echo integration-tests/ildasm-not-executable did not restore the execute bit

    exit 1
fi

echo integration-tests/ildasm-not-executable: PASS


exit 0
