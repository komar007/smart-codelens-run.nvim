# smart-codelens-run.nvim

Run the most suitable LSP codelens for a position in buffer.

## What it does

This plugin currently provides convenience features for working with executable codelenses provided
by some LSP servers, usually as means to run executable parts of programs and tests.

### Running remote codelenses

The problem with those codelenses is that they are assigned to a specific, usually short, range of
text (for example function name), and for [`vim.lsp.codelens.run`] to work, the cursor needs to be
on the line to which the codelens is attached. This means for example that being inside a test, one
often needs to jump to the function header of the test to execute it and then jump back.

The mapping `<Plug>(SmartCodelensRun)` provided by this plugin takes an optional register prefix
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
codelenses they produce which contains a range of code which defines the runnable/testable. For
[`rust-analyzer`] this would be for example the whole `main` function, the whole test function, or
the whole test module.

`smart-codelens-run` finds all the codelenses whose range contains the current line / marked
position and presents the user with a choice via `vim.ui.select`. This allows one to run the
runnable function / test they are currently working on without moving the cursor. For LSPs where
this is not supported (the range is not emitted), the user may fall back to defining a mark for the
test header and using the `"r` registere prefix.

[`vim.lsp.codelens.run`]: https://neovim.io/doc/user/lsp/#vim.lsp.codelens.run()
[`rust-analyzer`]: https://rust-analyzer.github.io/
[`vim.ui.select`]: https://neovim.io/doc/user/lua/#vim.ui.select()

## Installation & usage

With [lazy.nvim](https://github.com/folke/lazy.nvim):

``` lua
{
  "komar/smart-codelens-run.nvim",
  keys = {
    { "<leader>gC", "<Plug>(SmartCodelensRun)", desc = "run related codelens" },
  },
}
```
