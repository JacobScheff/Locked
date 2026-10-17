# GitHub setup for maintainers

These are repository settings that files in this checkout cannot enable. The repository was inspected on October 17, 2026; settings may change later. Apply these after pushing the open-source setup files.

## Already configured

- The repository is public and GitHub recognizes the MIT license.
- Issues and GitHub Actions are enabled.
- The default Actions token is read-only, and workflows cannot approve pull requests.
- Squash merging is enabled.

## Recommended changes

1. **Enable private vulnerability reporting.** It is currently disabled. In the repository's **Settings → Advanced Security**, enable **Private vulnerability reporting**. Verify that [Report a vulnerability](https://github.com/JacobScheff/Locked/security/advisories/new) works. This supplies the private reporting channel referenced in `SECURITY.md`. See [GitHub's instructions](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository).
2. **Enable secret scanning and push protection.** Both are currently disabled. Enable them in the repository's security settings, review any resulting alerts, and rotate any exposed credentials. See [GitHub's push protection guide](https://docs.github.com/en/code-security/how-tos/secure-your-secrets/prevent-future-leaks/enable-push-protection). An ignore rule does not remove files from Git history.
3. **Protect `main`.** No branch protection or repository rulesets were configured when inspected. Under **Settings → Rules → Rulesets**, create an active branch ruleset targeting `main`: require pull requests, require resolved conversations, require the `Build iOS` status check after its first successful CI run, and block force pushes and branch deletion. Enable strict/up-to-date status checks if desired. Keep required approval count at zero while you are the only maintainer; raise it when another trusted reviewer can approve your PRs. `CODEOWNERS` requests reviews but does not by itself enforce approval.
4. **Confirm Actions settings.** Under **Settings → Actions → General**, permit the official `actions/checkout` action used by CI and retain read-only default workflow permissions. Require approval for workflows from outside contributors, ideally all outside collaborators. The workflow uses `pull_request`, requests no secrets, and builds without signing. See [GitHub's Actions settings guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).
5. **Add repository metadata.** The description is currently empty. Suggested description: `An iOS app that connects coursework, rewards, and Screen Time app blocking.` Add topics such as `ios`, `swift`, `swiftui`, `screen-time`, and `productivity` from the repository's About panel.
6. **Enable automatic branch deletion** under **Settings → General → Pull Requests** if you want merged PR branches cleaned up. It is currently disabled.

## After the files reach GitHub

- Confirm the README, license, contribution guide, Code of Conduct, security policy, issue forms, and PR template appear correctly. GitHub's **Insights → Community Standards** page helps check discovery.
- Run **Actions → CI → Run workflow**, or open a pull request, and wait for `Build iOS`. Local checks on Windows cannot confirm an Xcode build. CI uses Xcode 26.3 on `macos-26`; update the toolchain path when that runner image retires it.
- Dependabot is configured to propose monthly GitHub Actions updates. There are currently no third-party application packages to monitor. Dependabot security updates were disabled when inspected; enable them if supported dependencies are added.
- Review security alerts and verify the maintainer's private reporting contact. Review the contents and history of any future files before publishing them. Existing Apple team, bundle, and App Group identifiers are public identifiers rather than signing secrets.
- Discussions are currently disabled and the wiki is enabled. Both are optional; enable Discussions if you want a Q&A space, or disable the wiki if all documentation will live in the repository.

No repository settings were changed by this setup. The existing MIT license was preserved.
