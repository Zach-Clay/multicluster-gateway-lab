# 0004 — Makefile as the single entry point

**Context.** Someone cloning this repo to evaluate it should be able to run it in one command.

**Decision.** A `Makefile` whose targets call one shell script each under `scripts/`. Make ships
with macOS and Linux, so there is nothing extra to install. Scripts are small and readable on
purpose: they are the documentation of each step.

**Alternatives.** Taskfile (nicer YAML, needs an install). Bare scripts (no discoverable `help`).

**Consequences.** Make's quirks (tabs, `$$`) are tolerated in exchange for zero setup.
