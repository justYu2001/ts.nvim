<p align="center">
  <h1 align="center">ts.nvim</h2>
</p>

<p align="center">
    TypeScript developer tooling for Neovim with intelligent auto-completion for utility types.
</p>

<div align="center">
    > Drag your video (<10MB) here to host it for free on GitHub.
</div>

<div align="center">

> Videos don't work on GitHub mobile, so a GIF alternative can help users.

_[GIF version of the showcase video for mobile users](SHOWCASE_GIF_LINK)_

</div>

## ⚡️ Features

- **Smart Auto-Completion for Utility Types**: Get intelligent suggestions when using `Omit`, `Exclude`, and `Extract`
- **Context-Aware**: Automatically detects when you're editing utility type parameters
- **LSP-Powered**: Leverages TypeScript LSP for accurate type information
- **Intelligent Caching**: Reduces LSP overhead with smart caching and invalidation
- **blink.cmp Integration**: Seamless integration with modern completion frameworks

## 📋 Installation

<div align="center">
<table>
<thead>
<tr>
<th>Package manager</th>
<th>Snippet</th>
</tr>
</thead>
<tbody>
<tr>
<td>

[wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)

</td>
<td>

```lua
-- stable version
use {"ts.nvim", tag = "*" }
-- dev version
use {"ts.nvim"}
```

</td>
</tr>
<tr>
<td>

[junegunn/vim-plug](https://github.com/junegunn/vim-plug)

</td>
<td>

```lua
-- stable version
Plug "ts.nvim", { "tag": "*" }
-- dev version
Plug "ts.nvim"
```

</td>
</tr>
<tr>
<td>

[folke/lazy.nvim](https://github.com/folke/lazy.nvim)

</td>
<td>

```lua
return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      return require("ts.integrations.blink").merge_opts(opts)
    end,
  },
  {
    "ts.nvim",
    version = "*"
  },
}
```

</td>
</tr>
</tbody>
</table>
</div>

## ⚙ Configuration

> The configuration list sometimes become cumbersome, making it folded by default reduce the noise of the README file.

<details>
<summary>Click to unfold the full list of options with their default values</summary>

> **Note**: The options are also available in Neovim by calling `:h ts.options`

```lua
require("ts").setup({
    -- Prints useful logs about what events are triggered
    debug = false,

    -- Auto-completion settings for TypeScript utility types
    auto_completion = {
        -- Cache time-to-live in milliseconds (default: 5000)
        cache_ttl = 5000,

        -- Maximum number of completion items to show for large types (default: 100)
        max_items = 100,
    },
})
```

</details>

## 🧰 Commands

|   Command   |         Description        |
|-------------|----------------------------|
|  `:Ts`      |  Toggles the plugin on/off |


## ⌨ Contributing

PRs and issues are always welcome. Make sure to provide as much context as possible when opening one.

## 🗞 Wiki

You can find guides and showcase of the plugin on [the Wiki](https://github.com/yu/ts.nvim/wiki)

## 🎭 Motivations

> If alternatives of your plugin exist, you can provide some pros/cons of using yours over the others.
