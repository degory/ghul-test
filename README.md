# ghūl compiler integration test runner

[![CI/CD](https://img.shields.io/github/actions/workflow/status/degory/ghul-test/cicd.yml?branch=main)](https://github.com/degory/ghul-test/actions?query=workflow%3ACICD+branch%3Amain)
[![NuGet version (ghul.test)](https://img.shields.io/nuget/v/ghul.test.svg)](https://www.nuget.org/packages/ghul.test/)
[![Release](https://img.shields.io/github/v/release/degory/ghul-test?label=release)](https://github.com/degory/ghul-test/releases)
[![Release Date](https://img.shields.io/github/release-date/degory/ghul-test)](https://github.com/degory/ghul-test/releases)
[![Issues](https://img.shields.io/github/issues/degory/ghul-test)](https://github.com/degory/ghul-test/issues) 
[![License](https://img.shields.io/github/license/degory/ghul-test)](https://github.com/degory/ghul-test/blob/main/LICENSE)
[![ghūl](https://img.shields.io/badge/gh%C5%ABl-100%25!-information)](https://ghul.io)

This is a very simple snapshot based test runner which is used by the [ghūl compiler](https://github.com/degory/ghul) [integration tests](https://github.com/degory/ghul/tree/master/integration-tests). It compares test expectations, in the form of snapshot text files, against the actual outputs of the compiler and test executables and flags any differences.


