#!/bin/bash

CASE=$1

if [ ! -d $CASE ] ; then
    echo "not run from a test case project"
    exit 1
fi

if [ ! -f $CASE/ghulflags ] ; then
    echo "not run from a test case project"
    exit 1
fi

if [ -d $CASE ] ; then
    if [ ! -f $CASE/failed ] ; then
        echo "expected to find failed marker in $CASE"
        exit 1
    fi

    if [ -f $CASE/err.sort ] ; then
        mv $CASE/err.sort $CASE/err.expected
    fi

    if [ -f $CASE/warn.sort ] ; then
        mv $CASE/warn.sort $CASE/warn.expected
    fi

    if [ -f $CASE/il.out ] ; then
        mv $CASE/il.out $CASE/il.expected
    fi
    
    for image in $CASE/*.png ; do
        if [ -f "$image" ] ; then
            cp "$image" "$image.expected"
        fi
    done

    # A run that ended abnormally records the status it ended with, so a
    # test whose subject is failing can assert it. A run that succeeded
    # leaves no expectation behind unless the test already carries one.
    if [ -f $CASE/run.exit ] ; then
        if [ "$(cat $CASE/run.exit)" != "0" ] || [ -f $CASE/run.exit.expected ] ; then
            mv $CASE/run.exit $CASE/run.exit.expected
        fi
    fi

    # The program's standard error becomes an expectation when it wrote
    # something there, or when the test already asserts that stream - a test
    # that says nothing about it keeps saying nothing.
    if [ -f $CASE/run.err ] ; then
        if [ -s $CASE/run.err ] || [ -f $CASE/run.err.expected ] ; then
            mv $CASE/run.err $CASE/run.err.expected
        fi
    fi

    if [ -f $CASE/run.out ] ; then
        mv $CASE/run.out $CASE/run.expected
        rm -f $CASE/fail.expected
    else
        echo >$CASE/fail.expected
    fi

    exit 0
else
    echo "doesn't seem to be a test case: $CASE"
    exit 1
fi
