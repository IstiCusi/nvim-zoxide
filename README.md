# nvim-zoxide

A neovim plugin that provides helpful wrappers around [zoxide].

This is [IstiCusi's fork](https://github.com/IstiCusi/nvim-zoxide) of
[alfaix/nvim-zoxide](https://github.com/alfaix/nvim-zoxide). The original Git
history, license, commands and Telescope integration are preserved.

The fork schedules process completion handlers on Neovim's main loop. Failed
queries, empty results and failed database updates can therefore display their
warnings without `E5560`. User callbacks also run on the main loop when a query
fails. Error messages remain visible; no notification or diagnostic is disabled.

## Features

* Out-of-the-box commands (`:Z[!]`, `:Zt[!]`, `:Zw[!]`)
* Lua interface
* Telescope integration

## Installation

Install the `zoxide` executable separately and make it available in `$PATH`, or
set `path` to its executable path. This plugin depends on [plenary.nvim] and,
optionally, on [telescope.nvim]. A complete [lazy.nvim] plugin-spec file is:

```lua
return {
  "IstiCusi/nvim-zoxide",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    -- Define Z[!], Zt[!] and Zw[!] for :cd, :tcd and :lcd.
    define_commands = true,
    path = "zoxide",
  },
}
```

If your Telescope specification already lists `alfaix/nvim-zoxide` as a
dependency, replace that entry with `IstiCusi/nvim-zoxide` and keep its existing
options. Use one specification for the plugin, rather than both repository
names. A `pin = true` added solely to protect local edits is no longer needed
once the fixed commit is published in your fork.

For Telescope, retain your existing setup and key mappings. Include
`extensions = { zoxide = {} }` in its setup options, and call
`require("telescope").load_extension("zoxide")` after
`require("telescope").setup(opts)`. The plugin must be available as a Telescope
dependency or already loaded at that point.

## Usage

If `define_commands` is set, you can `:Z[t|w][!]` to a zoxide pattern, e.g.:

* `:Z somedir` to match "somedir", open a `vim.ui.select` if there are multiple
  matches, then `:cd` to the selected (or only) match.
* `:Zt! somedir` to match "somedir" and immediately `:tcd` to the best match.

For telescope integration, run `:Telescope zoxide`, `:Telescope zoxide tab`,
`:Telescope zoxide window`, or use the corresponding [extensions api][telescope-extensions].

There's also lua interface available (`zoxide.zoxide`, `zoxide.increment`,
`zoxide.cd`) if you want to implement your own functions, see init.lua for
docstrings. It is callback-based but you can convert it to coroutines via
`plenary.async.wrap` or `nio`. For your own commands, just calling `zoxide.zoxide`
with appropriate context should
be sufficient.

## Validation

The regression suite passed 30 checks on each of Neovim **0.11.4** and
**0.12.6**, including the three Telescope directory scopes. These are tested
versions, not a guarantee for every future Neovim or dependency release.

Tests use real Plenary subprocesses and a deterministic CLI fixture to exercise
success, missing matches, empty output, selection cancellation and database
errors. They do not modify your actual zoxide database. See
[tests/README.md](tests/README.md) for commands and the recorded results.

## Alternatives
* Just the telescope integration: [telescope-zoxide](https://github.com/jvgrootveld/telescope-zoxide).
They also do extra pattern-based sorting on top of native zoxide.
* Vimscript plugin (no telescope): [zoxide.vim](https://github.com/nanotee/zoxide.vim/tree/master)

[zoxide]: https://github.com/ajeetdsouza/zoxide
[lazy.nvim]: https://github.com/folke/lazy.nvim/
[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[telescope-extensions]: https://github.com/nvim-telescope/telescope.nvim#extensions
[plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
