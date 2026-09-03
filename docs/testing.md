# Testing

We test to pin our own decisions, and each decision once. The suite should get
smaller when a change removes a reason to test, not reflexively larger when it
adds a feature. A pull request that only adds tests is as suspect as one that
adds none.

## Prefer unit tests

A unit test calls **one function** and asserts its return value or its direct
effect. Building the function's input — a payload dictionary, a model, an
`HaState` seeded through its own setters — is fixture setup, not part of the unit
under test. Chaining several functions-under-test and asserting the end result is
not a unit test.

Most of what we own is unit-testable this way: a builder takes an `HaState` and
returns a model, a parser takes a payload and returns models, `LevelRange`
returns a stepped value. Test the returned value; nothing downstream.

## Flow tests are allowed, but they must earn it

Some logic is orchestration — the `Coordinator` routing a fetch into state,
rebuilding a shown view when state changes — and there is no single function to
assert on. A flow test that drives the real objects through their public methods
is fine, but only when **all** of these hold:

- **No test-only wiring.** The test constructs the objects the way production
  does. If a test needs an accessor, a seam, or an injected dependency that
  exists for no reason but the test, the test is driving the design — not allowed.
  (Constructor-injecting a collaborator that production also injects is real
  composition, not test-only wiring.)
- **No assertions on the shape of a service call.** Asserting `sentService`,
  `sentField`, or `sentDomain` — the domain, service, and payload of a call —
  tests Home Assistant's contract, which we assume is always correct. Whether a
  request went out at all, how many, and which endpoint (a registration versus a
  webhook) is our own orchestration and is fair to assert; the body we hand
  Home Assistant is not.
- **It pins something no other test covers.** A flow that re-asserts what the
  unit tests of its collaborators already pin is redundant and comes out — even
  though it would otherwise be allowed.

## Never test the same thing twice

This governs the choice between a unit test and a flow test. When a flow test
genuinely covers a behaviour, the unit tests that only re-cover the same ground
*through* it can come out; when the units are the honest home, the flow that
duplicates them comes out. Pick the single place that pins each behaviour best,
and delete the other. The goal is no behaviour tested twice — in either
direction.

## What we do not test here

`make test` runs in the simulator with no network. Anything that needs the
network — the shape of a request, whether Home Assistant honours a service call —
is verified in the simulator or on device, not in this suite. Home Assistant's
own behaviour is assumed correct and is never asserted.
