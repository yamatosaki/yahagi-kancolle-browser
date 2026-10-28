# Contributing Guide

[简体中文](CONTRIBUTING.md) ｜ English ｜ [한국어](CONTRIBUTING.ko.md)

Issues and pull requests to improve Yahagi are welcome.

To build a copy for personal use, start with [Building and Verifying from Source](BUILDING.en.md). For themes, text, assets, or an independent fork, see the [Customization Guide](CUSTOMIZING.en.md).

## Development Workflow

1. Fork the repository and create a feature branch from the default branch.
2. Keep changes focused and add tests for behavior changes.
3. Do not commit account data, API request or response bodies, cookies, tokens, signing keys, or machine-specific configuration.
4. Set up your environment using [Building and Verifying from Source](BUILDING.en.md), and run the checks in that guide before committing.
5. In your pull request, explain the motivation, scope of impact, test results, and anything that needs manual verification.

## Code and Assets

- Format Dart code with `dart format`.
- Logs and error messages exposed to users or external systems must not contain sensitive request data.
- When adding third-party dependencies or assets, update `THIRD_PARTY_NOTICES` and ensure their licenses permit distribution with the repository and app.
- Do not commit `test/failures/`, build artifacts, IDE configuration, or signing files.
