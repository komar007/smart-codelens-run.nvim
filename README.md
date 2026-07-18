# 🧠🔎🏃‍➡️smart-codelens-run.nvim

Run the most suitable LSP codelens for a given position in buffer.

<!--toc:start-->
- [🧠🔎🏃‍➡️smart-codelens-run.nvim](#🧠🔎🏃‍️smart-codelens-runnvim)
  - [What it does](#what-it-does)
    - [Running remote codelenses](#running-remote-codelenses)
    - [Running codelenses associated with the cursor position](#running-codelenses-associated-with-the-cursor-position)
  - [Installation & usage](#installation-usage)
  - [`<Plug>` mappings](#plug-mappings)
    - [`<Plug>(smart-codelens-run)`](#plugsmart-codelens-run)
    - [`<Plug>(smart-codelens-run-one)`](#plugsmart-codelens-run-one)
    - [`<Plug>(smart-codelens-run-mark)`](#plugsmart-codelens-run-mark)
    - [`<Plug>(smart-codelens-run-one-mark)`](#plugsmart-codelens-run-one-mark)
    - [`<Plug>(smart-codelens-run-at)`](#plugsmart-codelens-run-at)
      - [Example](#example)
    - [`<Plug>(smart-codelens-run-one-at)`](#plugsmart-codelens-run-one-at)
  - [Lua API](#lua-api)
    - [`run(opts?)`](#runopts)
    - [`run_at(bufnr, row, opts?)`](#runatbufnr-row-opts)
    - [`run_at_mark(mark, opts?)`](#runatmarkmark-opts)
<!--toc:end-->

## What it does

This plugin provides convenience features for working with executable codelenses provided by some
LSP servers (usually as means to run executable parts of programs and tests).

### Running remote codelenses

The problem with those codelenses is that they are assigned to a specific, usually short, range of
text (for example function name), and for [`vim.lsp.codelens.run`] to work, the cursor needs to be
on the line to which the codelens is attached. This means for example that being inside a test, one
often needs to jump to the function header of the test to execute it and then jump back.

The mapping [`<Plug>(smart-codelens-run)`](#plugsmart-codelens-run) provided by this plugin takes an
optional register prefix (`"r`) and executes a codelens attached to the line at the position marked
by the mark of the same name as the passed register. It may be an unconventional approach, but it
allows the use of just one mapping for a running on the current line (the default, if the register
prefix is not used) and on a selected mark. *This interface may be subject to change, depending on
how convenient it proves to be in practice. Taking a motion / single-character register as argument
may be used instead/added*.

This enables a workflow where a mark is placed in a location of a codelens that runs a
runnable/testable, and then the test can be quickly invoked between changes elsewhere, including
other files.

### Running codelenses associated with the cursor position

Some LSP servers (currently, only [`rust-analyzer`] is supported) attach extra information to the
codelenses they produce which contains a range of code which spans the runnable/testable. For
[`rust-analyzer`] this would be for example the whole `main` function, the whole test function, or
the whole test module.

For LSP servers that do not attach such information (most likely all except [`rust-analyzer`]), a
treesitter-based heuristic is used to expand the range provided by the codelens to the whole
runnable/testable.

`smart-codelens-run` finds all the codelenses whose expanded range contains the current line /
marked position and presents the user with a choice via [`vim.ui.select`]. This allows one to run
the runnable function / test they are currently working on without moving the cursor.

## Installation & usage

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
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

> [!NOTE]
> Passing a mark via register prefix is a questionable idea but seemed convenient at first. See
> [`<Plug>(smart-codelens-run-mark)`](#plugsmart-codelens-run-mark) and
> [`<Plug>(smart-codelens-run-at)`](#plugsmart-codelens-run-at) for better alternatives.

When more than one codelens matches the target position, a [`vim.ui.select`] dialog is presented.
Lenses attached directly to the target line are prioritized; among lenses whose expanded range
contains the target, smaller ranges are preferred (e.g. a function body over a whole module).

### `<Plug>(smart-codelens-run-one)`

Like [`<Plug>(smart-codelens-run)`](#plugsmart-codelens-run), but skips the selection dialog. When
multiple codelenses match, the best match (same prioritization rules) is executed immediately.

### `<Plug>(smart-codelens-run-mark)`

Reads a single mark character after the mapping and runs a codelens at that mark's position. This is
an alternative to the questionably vim-like register-prefix interface of
[`<Plug>(smart-codelens-run)`](#plugsmart-codelens-run) — press the mapping, then the mark letter
(e.g. `gCr` to run at mark `r`). When more than one codelens matches, a [`vim.ui.select`] dialog is
presented.

### `<Plug>(smart-codelens-run-one-mark)`

Like [`<Plug>(smart-codelens-run-mark)`](#plugsmart-codelens-run-mark), but skips the selection
dialog. The best matching codelens is executed immediately.

### `<Plug>(smart-codelens-run-at)`

Operator-pending mapping. Runs a codelens at the position the motion passed as operator would put
the cursor at. When more than one codelens matches, a [`vim.ui.select`] dialog is presented.

This is a generalization of [`<Plug>(smart-codelens-run-mark)`](#plugsmart-codelens-run-mark) and a
more (neo)vim-idiomatic way of running a codelens at a position indicated by a mark (use `'m` as
operator) than using a register prefix in [`<Plug>(smart-codelens-run)`](#plugsmart-codelens-run).
It is likely of little use with other operators.

#### Example

With the following mapping:

```lua
vim.keymap.set('n', 'gC', '<Plug>(smart-codelens-run-at)')
```

- `gC'r` runs a codelens at the position indicated by register `r` in the current buffer,
- `gCgg` runs a codelens at the beginning of the buffer without moving the cursor,
- `gC10j` runs a codelens 10 lines down from the cursor position.

### `<Plug>(smart-codelens-run-one-at)`

Like [`<Plug>(smart-codelens-run-at)`](#plugsmart-codelens-run-at), but skips the selection dialog.
The best matching codelens is executed immediately.

## Lua API

Example:

```lua
require('smart-codelens-run').run({ select = true })
```

### `run(opts?)`

Run a codelens.

| Parameter     | Type       | Default | Description                                                                                                                          |
| ------------- | ---------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `opts`        | `table?`   | `{}`    | Optional configuration table.                                                                                                        |
| `opts.select` | `boolean?` | `true`  | When `true` and more than one codelens matches, show a `vim.ui.select` picker. When `false`, the best match is executed immediately. |

The target position is determined by `vim.v.register`:

- default (no register prefix): uses the current cursor position,
- with a register prefix (e.g. `"r`): uses the position stored in mark `r`.

### `run_at(bufnr, row, opts?)`

Run a codelens at a specific position indicated by buffer and row number. Use this to
programmatically execute a codelens at an arbitrary location without relying on marks or cursor
position.

| Parameter | Type      | Default | Description                  |
| --------- | --------- | ------- | ---------------------------- |
| `bufnr`   | `integer` | —       | Buffer number.               |
| `row`     | `integer` | —       | 1-based row number.          |
| `opts`    | `table?`  | `{}`    | see [`run(opts?)`](#runopts) |

### `run_at_mark(mark, opts?)`

Run a codelens at a named mark. This is the programmatic equivalent of
[`<Plug>(smart-codelens-run-mark)`](#plugsmart-codelens-run-mark) and
[`<Plug>(smart-codelens-run-one-mark)`](#plugsmart-codelens-run-one-mark).

| Parameter | Type     | Default | Description                              |
| --------- | -------- | ------- | ---------------------------------------- |
| `mark`    | `string` | —       | Single-character mark name (e.g. `'r'`). |
| `opts`    | `table?` | `{}`    | see [`run(opts?)`](#runopts)             |

[`rust-analyzer`]: https://rust-analyzer.github.io/
[`vim.lsp.codelens.run`]: https://neovim.io/doc/user/lsp/#vim.lsp.codelens.run()
[`vim.ui.select`]: https://neovim.io/doc/user/lua/#vim.ui.select()
