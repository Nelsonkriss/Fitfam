# Contributing to Fitfam

Thank you for your interest in contributing to Fitfam! We welcome bug reports, feature requests, and pull requests.

## Coding standards

- **Style:** Follow the Dart code style guidelines. For Python code (scripts, CI), adhere to PEP 8—readability and consistency are key.
- **Documentation:** Write clear docstrings for all public classes, functions and modules. Use triple-quoted strings and summarize one-line docstrings on a single line.
- **Error handling:** Avoid broad `catch` statements. Catch specific exception types and avoid masking errors.

## Security practices

- Never commit API keys, secrets or personal data to the repository. Use environment variables or configuration files listed in `.gitignore`.
- Enable secret scanning (GitHub secret scanning or tools like truffleHog) to detect accidental secrets.
- Keep dependencies up-to-date using tools like Dependabot or Renovate.

## Creating pull requests

1. Fork the repository and create a branch for your change.
2. Make your changes with descriptive commit messages.
3. Ensure all tests pass and add new tests if necessary.
4. Submit a pull request with a clear description of your changes and the rationale behind them.

Thank you for helping make Fitfam better!
