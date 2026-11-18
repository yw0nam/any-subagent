# Writing tests

Read before writing or changing a test. These rules cover what review judges; lint and CI check the rest. They apply to every language in the repository; each language keeps its own test layout, parameterisation and mocking tools.

## What a test is for

A test earns its place by what its failure means: a behaviour a user sees, a contract, a config schema, a wire frame, or an exported function's documented result is broken. A test whose failure means none of these is noise and is not written.

Not tested: an implementation constant's value in isolation (a value that is itself a documented contract is a contract), a library's or the platform's behaviour, a call on an internal helper, a call on a collaborator that no caller can observe, and a fact a sibling test already asserts. A collaborator call is observable when it crosses the module's external boundary: OS, network, UI or storage I/O; a dependency passed in as an argument is one way that boundary is exposed.

The same setup with another input is a row in the sibling's parameterised table, not a new test. A file's test count is not a measure of coverage.

## Placement and names

1. A test sits beside the code it pins, and its file name starts with that source file's name, following the language's convention (`x.test.ts`, `x_test.go`, `test_x.py`). A test that pins a feature folder through its public entry takes the feature's name.
2. A test file is named after the code it pins. A fix, an issue, or a PR never names it.
3. Before adding a test, read the existing tests of the same unit. The same setup with another input is a new row in that file's table.

## Assertions

4. Call the public entry: the exported function, the factory, the UI event, the HTTP route. A test of the helper behind it stays green when the entry stops calling the helper.
5. Expected values are literals. A value computed by the code under test, or read from a production constant, moves with that code.
6. Assert the exact value. A check that something is defined, truthy or non-empty, or that any error was raised, also passes for a wrong value; an error check names the message or the error type.

## Red before green

7. For new behaviour, the `test:` commit fails when run on its own, before the `feat:` or `fix:` commit. A bug fix that ships a test shows that test failing without the fix.
8. A test added to behaviour that already works is shown failing: change the production line its path takes in a throwaway worktree, watch the test fail, restore the line. The PR body names that line.

## Existing tests

9. An existing test is never deleted, skipped, or loosened to turn a run green. When behaviour changes on purpose, the PR summary lists each changed assertion and its reason. A test that meets § What a test is for may always be written. A PR that touches a test file repairs or folds its tests while keeping every distinct behaviour and contract covered, and deletes a test that pins neither; a failing assertion is never removed in place of fixing the behaviour or revising its contract on purpose. The PR summary lists each deleted test with its reason.

## Mocks and outside services

10. A module of this repository that a test replaces is passed in as an argument where the code takes one. A mocking library covers only what a test cannot pass in: the platform, a third-party SDK, the network.
11. A mock is typed against the real module, so a changed signature breaks the test at compile time.
12. A test that reaches a real service is gated by an environment variable and the service's key, and CI skips it. Here no test reaches a real backend: `tests/agent-send.test.sh` runs against stub CLIs on PATH, and a real CLI is checked by hand through the live acceptance checks in `docs/adding-a-backend.md`.
