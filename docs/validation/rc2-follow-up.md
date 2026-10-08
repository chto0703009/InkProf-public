# RC2 follow-up validation — 2026-10-08

This record concerns local changes **after** the published v1.0.0-rc.2 tag.
It does not replace the historical release check or claim that published RC2
contains these fixes. Base commit: `cb1afa0`; this follow-up tests the
local working changes. Environment: macOS, MATLAB R2025b, the configured
Python 3.13 environment and ArgyllCMS 3.5.0.

## Changes reviewed

- Approval and project-details dialogs: preserve a dismissed state when Cancel, Close or Approve
  occurs before `uiwait`; avoid waiting again after an early response.
- Dialog tests: retry until controls exist, initialise graphics before timers,
  add a 45-second test-only deadline, and dispose deadline timers after each
  test. A deadline expiry is a test failure, not a successful cancellation.
  Existing image-dialog watchdogs remain in place.
- ICC test: byte-identical import/save uses a v2 fixture. A v4 profile requires
  explicit consent and approximate reconstruction; the separate v4 test checks
  cancellation without creating a compatibility copy.
- Portable report test: verify the inline measured-colour section and all
  linked external files, decoding URL-escaped filenames. Do not require a
  separate image when the current report embeds an interactive plot.
- Paper-size tests: permit configurable field limits and explicitly set a
  420 mm measurement length for the long-page test; project limits still apply.
- Definition import: normalise a character-vector Source to a MATLAB string
  before combining its filename stem and extension. Previously `stem + ext`
  could add character codes and produce an invalid filename. A regression test
  covers character-vector input.

## UI workflow check

A separate temporary project with 24 synthetic RGB patches was used. The
workflow window was rendered and visually inspected before and after TIFF16
creation. Definition completion, TIFF readiness/completion, measurement
readiness, locked downstream steps, saved identities, project integrity and
reopening were checked. This combines scripted UI checks and human visual
inspection of exported window images; it is not a complete manual click-through
or a physical instrument/print test. Native UI automation could not attach to
this batch MATLAB window.

No user project, original measurement or delivered ICC was changed.

## Scope still requiring separate work

The public checkout excludes private reference fixtures. Replacing those with
public synthetic fixtures was explicitly outside this follow-up (item 1 was
not requested). A full development-suite result must not be described as a full
public-source qualification. Physical printing, hardware measurement and fresh
installation also remain outside this automated check.

## Reproduction

Run from the development checkout with the required private fixtures present:

```matlab
addpath('src'); addpath('tests');
% Initialise the UI before starting timer-driven dialog tests.
f = uifigure('Visible','off'); drawnow; delete(f);
r = runtests('tests');
disp(table(r));
assertSuccess(r);
```

Set `INKPROF_TEST_PYTHON` to the configured InkProf Python interpreter.
The full run includes actual Argyll profile builds using synthetic measurements;
those numerical results do not establish physical print accuracy.

## Results

- Full MATLAB discovery completed: **210 passed, 1 failed, 0 incomplete**
  (631.2 seconds). The only remaining failure was the old `lengthPolicy`
  expectation in `testRenderDialog/testLongPageMetadata`.
- After correcting that test expectation, the **entire render-dialog test file
  passed: 4 passed, 0 failed, 0 incomplete**. It also verifies the explicitly
  configured 420 mm limit. No production code changed after the full run.
- **All 211 unique discovered MATLAB tests have a passing latest result**,
  using the full run plus the corrective retest. This is cumulative evidence,
  not a claim that the full run itself had zero failures.
- Approval, project-details Save/Cancel, character-vector target import,
  measurement dialogs/revisions, ICC cancellation, four real Argyll profile
  builds, gradient diagnostics, report delivery and package integrity were
  included. No tests were skipped to obtain these totals.
- Separate temporary-project UI/render/reopen/integrity smoke check passed;
  exported workflow windows were visually inspected. Full manual click-through
  remains open because native UI access was unreliable.
- Source/version/resource notices and `git diff --check` passed.

Individual latest results and the unmodified full-run/retest totals are in
[the structured test record](rc2-matlab-follow-up-results.json). The published
RC2 tag/assets were not changed by this follow-up.
