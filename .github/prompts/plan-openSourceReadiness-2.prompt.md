# Plan: Open-Source Readiness for SSTV-MEL

The repo is in **excellent shape** — a previous 17-step readiness plan was executed covering licensing, documentation, CI, testing, and code quality. However, several items still need attention before flipping the repo to public.

## Status

**3 of 16 steps complete.** Steps 1, 7 already done. Repo is still **private**. 14 stale local branches to clean up.

## Steps

### Blockers (must complete before making public)

1. ~~**Push LFS-rewritten history to remote**~~ — **DONE.** Local and remote `main` are in sync at `6be380b`. All 5 tags (`0.1.0`, `0.2.0`, `v0.3.0`, `v0.5.0`, `v0.6.0`) are on the remote. 21 WAV files tracked via Git LFS.

2. **Remove internal planning file** — Delete `.github/prompts/plan-openSourceReadiness.prompt.md` (the *old* plan file, not this one). This is a detailed internal process document tracking how the repo was prepared for open source. It's not harmful, but it's internal tooling noise that a public visitor shouldn't see.

3. **Add attribution to `docs/sstv_05.pdf`** — The PDF is from https://www.sstv-handbook.com/download/sstv_05.pdf but has zero attribution in the repo. Add a note — either a `docs/sstv_05-ATTRIBUTION.md` file, a line in `docs/NEXT-STEPS.md`, or a comment in the README project layout section — stating the source URL and that it's a publicly available SSTV specification reference.

4. **Fix stale `docs/PD120-Implementation.md`** — This file has three issues:
   - VIS code listed as `0x63` (should be `0x5F` per the actual `PD120Mode.swift`)
   - File paths reference `Sources/sstv/...` (old structure); should be `Sources/SSTVCore/...`
   - Line structure describes single-line YCbCr; current implementation uses 2-lines-per-frame
   
   Either update it to match reality or add a prominent deprecation notice at the top pointing to the ADR.

5. **Set the GitHub repository to public** — Currently private. After completing all other blocker steps, go to Settings → Danger Zone → Change visibility → Public.

### Recommended (before or shortly after going public)

6. **Update GitHub repo metadata** — Current description is stale ("SSTV decoding prototype"). Update to something like "Swift SSTV decoder — library + CLI for decoding SSTV audio to images". Add Topics (e.g. `sstv`, `swift`, `amateur-radio`, `ham-radio`, `dsp`, `signal-processing`, `spm`). No topics are currently set.

7. ~~**Create a GitHub Release for v0.6.0**~~ — **DONE.** Release `v0.6.0` exists with full release notes.

8. **Add Robot36 golden reference images** — `expected/` has `PD120/` and `PD180/` directories but no `Robot36/`. The `Robot36ModeTests.swift` exists but can't do full golden-file comparison without reference images. Generate and commit `expected/Robot36/` references.

9. **Add SwiftLint to CI** — `.swiftlint.yml` is configured and produces 0 errors / 8 warnings, but it's not enforced in `.github/workflows/ci.yml`. Add a `swiftlint` step to catch regressions from contributors.

10. **Fix path casing in copilot test instructions** — `.github/copilot/copilot-tests.md` line 15 references `/Samples` (capital S); the actual directory is `samples/` (lowercase). Minor but could confuse AI-assisted contributors.

11. **Track `docs/sstv_05.pdf` in Git LFS** — `.gitattributes` only tracks `*.wav`. The PDF is a binary file that shouldn't be diffed. Add `*.pdf filter=lfs diff=lfs merge=lfs -text` to `.gitattributes` and migrate it.

### Nice-to-have (post-launch polish)

12. **Set up branch protection on `main`** — Require PR reviews, status checks (CI passing), and disallow force-pushes. Protects against accidental breakage from contributors.

13. **Register on Swift Package Index** — Submit to swiftpackageindex.com so the library is discoverable by other Swift developers who might want to integrate SSTV decoding.

14. **Add a social preview image** — A decoded SSTV image as the repo's social preview (Settings → Social preview) gives the repo visual appeal when shared on social media.

15. **Consider `FUNDING.yml`** — If you want to accept sponsorships, add `.github/FUNDING.yml` with your GitHub Sponsors or other funding links.

16. **Clean up legacy dead code in `SSTVDecoder.swift`** — Contains `findSignalStart`, `upsampleFrequencies`, and `exportFrequencyDebug` methods marked as legacy/commented. Removing these reduces confusion for new contributors reading the codebase.

17. **Clean up 14 stale local branches** — There are 14 local branches whose remote tracking branches are gone. Run `git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D` to clean them up. Optional but reduces clutter.

## Verification

- ~~After step 1: Clone the repo fresh, confirm `git lfs pull` fetches WAV files and `swift build && swift test` passes~~ — **LFS confirmed in sync.**
- After step 5: Visit https://github.com/kevinnz/SSTV-MEL in an incognito browser — confirm it loads, README renders, CI badge (if added) shows green
- Review the repo as a first-time visitor: read README → try to build → look at CONTRIBUTING.md → open an issue using the template

## Decisions

- Copilot instruction files in `.github/copilot/` — **keep**. They're clean technical guidance that help AI-assisted contributors
- Internal docs in `docs/internal/` — **keep**. They're clearly labeled as historical artifacts with a disclaimer README
- Per-file license headers — **skip**. Not required for MIT; the root LICENSE file covers everything
