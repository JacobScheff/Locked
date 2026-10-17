# Contributing to Locked

Bug reports, documentation improvements, and focused pull requests are welcome. Follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

Search existing issues and pull requests. Open an issue to discuss substantial features or behavior changes before investing in a large implementation. For vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of posting details publicly.

Fork the repository, create a branch from `main`, and follow the build and signing instructions in [README.md](README.md). Keep changes scoped to one problem. Match the surrounding Swift style and avoid unrelated formatting or Xcode project changes.

## Validation

Run on a Mac with Xcode 26.3 or newer:

```sh
bash scripts/build.sh
bash scripts/build.sh Release
git diff --check
```

The script validates tracked property lists and compiles the app and embedded extensions without signing. GitHub Actions runs the Debug build on pull requests and pushes to `main`. The repository does not currently contain automated unit or UI test targets; a successful build does not verify runtime behavior.

For affected features, also check on a physical device:

- Course creation, assignment editing, completion rewards, and persistence after relaunch.
- Screen Time authorization, app selection, usage reports, and shield updates across app and extension boundaries.
- Key spending, emergency override activation, and expiration restoring the expected shields.
- Widget updates after coursework or reward changes.
- Provider sign-in, refresh, session expiration, and disconnect for changed school integrations.

Use synthetic coursework and redacted samples in reports and fixtures. Never commit passwords, session cookies, tokens, school account exports, signing keys, or provisioning profiles. Keep personal team and bundle identifier changes out of unrelated pull requests.

## Submit a pull request

Explain the problem, resulting behavior, and validation performed. Include screenshots for visible UI changes with personal and student information removed. If you could not run a check, say so and explain why. Link any related issue.

Contributions are accepted under the repository's existing [MIT License](LICENSE). No separate contributor license agreement is required by this repository.
