# smart-codelens-run.nvim

Run the most suitable LSP codelens for a given position in buffer.

## What it does

This plugin provides convenience features for working with executable codelenses provided by some
LSP servers (usually as means to run executable parts of programs and tests).

### Running remote codelenses

The problem with those codelenses is that they are assigned to a specific, usually short, range of
text (for example function name), and for [`vim.lsp.codelens.run`] to work, the cursor needs to be
on the line to which the codelens is attached. This means for example that being inside a test, one
often needs to jump to the function header of the test to execute it and then jump back.

The mapping `<Plug>(smart-codelens-run)` provided by this plugin takes an optional register prefix
(`"r`) and executes a codelens attached to the line at the position marked by the mark of the same
name as the passed register. It may be an unconventional approach, but it allows the use of just one
mapping for a running on the current line (the default, if the register prefix is not used) and on a
selected mark. *This interface may be subject to change, depending on how convenient it proves to be
in practice. Taking a motion / single-character register as argument may be used instead/added*.

This enables a workflow where a mark is placed in a location of a codelens that runs a
runnable/testable, and then the test can be quickly invoked between changes elsewhere, including
other files.

### Running codelenses associated with the cursor position

Some LSP servers (currently, only [`rust-analyzer`] is supported) attach extra information to the
codelenses they produce which contains a range of code which spans the runnable/testable. For
[`rust-analyzer`] this would be for example the whole `main` function, the whole test function, or
the whole test module.

For LSP servers that do not attach such information (most likely all except [`rust-analyzer`]),
a treesitter-based heuristic is used to expand the range provided by the codelens to the whole
runnable/testable.

`smart-codelens-run` finds all the codelenses whose expanded range contains the current line /
marked position and presents the user with a choice via [`vim.ui.select`]. This allows one to run
the runnable function / test they are currently working on without moving the cursor.

[`vim.lsp.codelens.run`]: https://neovim.io/doc/user/lsp/#vim.lsp.codelens.run()
[`rust-analyzer`]: https://rust-analyzer.github.io/
[`vim.ui.select`]: https://neovim.io/doc/user/lua/#vim.ui.select()

## Installation & usage

With [lazy.nvim](https://github.com/folke/lazy.nvim):

``` lua
{
  'komar007/smart-codelens-run.nvim',
  keys = {
    { "gC", "<Plug>(smart-codelens-run)", desc = "Run related codelens" },
  },
}
```

## `<Plug>` mappings

### `<Plug>(smart-codelens-run)`

Run the codelens most closely associated with the cursor position (or the position of a mark passed
via register prefix, e.g. `"r<Plug>(smart-codelens-run)`).

When more than one codelens matches the target position, a [`vim.ui.select`] dialog is presented.
Lenses attached directly to the target line are prioritized; among lenses whose expanded range
contains the target, smaller ranges are preferred (e.g. a function body over a whole module).

### `<Plug>(smart-codelens-run-one)`

Like `<Plug>(smart-codelens-run)`, but skips the selection dialog. When multiple codelenses match,
the best match (same prioritization rules) is executed immediately.

## Lua API

Example:

```lua
require('smart-codelens-run').run({ select = true })
```

### `run(opts?)`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `opts` | `table?` | `{}` | Optional configuration table. |
| `opts.select` | `boolean?` | `true` | When `true` and more than one codelens matches, show a `vim.ui.select` picker. When `false`, the best match is executed immediately. |

The target position is determined by `vim.v.register`:

- default (no register prefix): uses the current cursor position,
- with a register prefix (e.g. `"r`): uses the position stored in mark `r`.
