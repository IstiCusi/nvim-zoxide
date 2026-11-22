# Regression tests

Requirements: Python 3, Neovim, and an installed `plenary.nvim` checkout.
An installed `telescope.nvim` checkout enables the picker integration tests.
No Python packages are required.

From the repository root:

```sh
python3 tests/run.py \
  --nvim /path/to/nvim \
  --plenary /path/to/plenary.nvim \
  --telescope /path/to/telescope.nvim \
  --report /tmp/nvim-zoxide-results.json
```

The suite invokes actual Plenary processes and real Telescope pickers. A small
Python executable supplies deterministic CLI output, including errors that
would be difficult to reproduce reliably against a user's database. The real
`zoxide` executable and its ranking/database implementation are not under test.
`vim.ui.select` is replaced only for deterministic selection and cancellation;
the plugin callbacks still run asynchronously. The Telescope tests use the
actual picker, finder and selection action in headless Neovim.

The tests cover:

- Configurable executable and optional command definitions.
- Successful, failed and empty queries; callbacks run once with the original
  context and may call editor APIs in each case.
- Multiple-result selection, cancellation and a single result in list mode.
- Failed database updates and successful adds.
- Global, tab-local and window-local working-directory behavior.
- Preservation of the directory after a failed command.
- Telescope selection in all three directory scopes.
- Visible expected warnings, with no fast-event notifications, editor errors,
  callback tracebacks or deprecated API calls in the tested workflows.

The checked-in reports record **30 passing checks per version**:

| Neovim | Report |
| --- | --- |
| 0.11.4 | [neovim-0.11.4.json](results/neovim-0.11.4.json) |
| 0.12.6 | [neovim-0.12.6.json](results/neovim-0.12.6.json) |

Each report includes the tested plugin source SHA-256 and the Plenary/Telescope
commits. Temporary directory names in reports belong to isolated test runs.

As a negative control, the same tests were run against the unchanged upstream
commit `aa534735d9cc76d2d3afbb93f61ea77305e2b349` under Neovim 0.11.4. That
run failed on a missing-match query with `E5560`, before invoking the user
callback. To reproduce this comparison, add `--plugin /path/to/upstream-checkout`
to the command above. The fixed checkout supplies the test runner in both cases.
