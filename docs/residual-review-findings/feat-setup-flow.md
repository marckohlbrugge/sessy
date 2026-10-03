# Residual Review Findings — feat/setup-flow

Source run: `ce-code-review mode:agent` for `docs/plans/2026-10-03-001-feat-setup-flow-plan.md`, branch `feat/setup-flow` at `8a380e1`.

Coverage note: the review ran in a single context (correctness, Hotwire races, accessibility, public-repo hygiene and plan-completeness lenses applied in-thread; the harness could not dispatch independent reviewers), and the cross-model peer was skipped because the Codex CLI returns 401 in this environment. Findings below are therefore uncorroborated. `bin/brakeman` reported no warnings. No tracker tickets were filed: every residual is P3 and below the ticket threshold, so this file is the durable record.

## Residual Review Findings

- P3 · `app/javascript/controllers/clipboard_controller.js:14` · `navigator.clipboard` is undefined on insecure origins (a self-hosted install served over plain HTTP from a non-localhost address), so the copy button rejects silently with no visual feedback. KTD8 scopes out a visible fallback; a follow-up could reveal the textarea on failure.
- P3 · `app/views/setups/_step_send.html.erb:13` · The code-sample tabs expose `role="tab"`/`aria-selected` but not the arrow-key navigation the WAI-ARIA tabs pattern describes; each tab is still reachable with Tab. Cosmetic for three buttons.
- P3 · `app/views/setups/_step_done.html.erb:1` · The `readonly` local is accepted but unused: step 3 is always the current step, so the strict-locals signature only exists so `show.html.erb` can render every step partial the same way.
- Judgment call recorded for the product owner · plan KTD6 · The brief listed the identity-default CLI command both as a toggle option and as a More-options item on step 2; it is the third toggle option only, so one sample at a time holds and nothing is listed twice.
- Judgment call recorded for the product owner · plan KTD4 · Earlier steps reopen read-only through `?step=N` (clamped to the current step) rather than a nested disclosure, and after a region save "More options" stays open once so the permanent `<select>` keeps focus and the commands show the change.
