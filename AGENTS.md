# Agent Instructions

When creating or rewriting Git commits in this repository, follow the Fuchsia
commit message style guide:

https://fuchsia.dev/fuchsia-src/contribute/commit-message-style-guide

Use this format:

```text
[scope] Imperative subject line

Explain what changed and why. Wrap body lines at about 72 characters.
Keep the message self-contained and avoid relative time references,
private URLs, credentials, user names, or unnecessary narrative.

Test: Describe verification, or use "None; <reason>."

Change-Id: I<gerrit-change-id>
```

Rules to remember:

- Start the subject with a useful bracketed scope, such as `[docker]` or
  `[docs]`.
- Write the subject in imperative mood, capitalized, and without a trailing
  period.
- Keep the subject concise, preferably near 50 characters.
- Add a blank line between the subject, body, trailers, and `Change-Id`.
- Preserve existing `Change-Id:` trailers when rewriting commits.
- Add `Test:` information for each commit. Use `None; documentation change
  only.` or another clear reason when no runtime test is needed.
