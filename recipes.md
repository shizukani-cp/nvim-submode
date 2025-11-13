# RECIPES
## CAPSLOCK submode

In CapsLock submode, all alphabets are capitalized. Since it is intended to be used in insert mode, assign the insert mode keymap to activate it.
`<any>` means to match any single character key. The counting function is not necessary in this mode, so it is turned off. The first return value of the action function (the function assigned to the rhs of the submode) sets the string actually sent to nvim. Also, you can exit the submode after executing the key binding by setting `sm.EXIT_SUBMODE` to the second return value. You can also exit the submode by pressing `<Esc>`. In this example, `<C-l>` is set as the submode trigger.

```lua
local capslock_sm = sm.build_submode({
  name = "CAPSLOCK",
  timeoutlen = 300,
  color = "#999999", -- Or use any color scheme you like
  is_count_enable = false,
  after_enter = function()
    vim.schedule(function()
      require("lualine").refresh()
    end)
  end,
  after_leave = function()
    vim.schedule(function()
      require("lualine").refresh()
    end)
    vim.notify("EXIT CAPSLOCK")
  end
}, {
  {
    '<any>',
    function(count, keys, anys)
      return string.upper(sm.replace_any(keys, anys))
    end
  },
  {
    '<C-l>',
    function(_, _, _)
      return "", sm.EXIT_SUBMODE
    end
  }
})

-- keymap
vim.keymap.set('n', '<C-l>', function()
  sm.enable(capslock_sm)
end)
```

## Clever-F Submode

Clever-F submode partially emulates [clever-f.vim](https://github.com/rhysd/clever-f.vim). `f<any>`, `F<any>` behave the same as the default f/F in Neovim. On the other hand, `f/F` alone behaves the same as `;/,` (searching forward/backward for the same character as the previous search result), respectively. `;/,` is also set up the same as the default. It also supports repeating operations using count. `sm.enable` takes a second argument that specifies the "contents of the buffer when the submode starts." In this case, it recreates the state when `f`, `F` are entered, and starts the submode and search at the same time.

```lua
local sm_clever_f = sm.build_submode({
  name = "CLEVER-F",
  timeoutlen = 300,
  color = colors.purple,
  after_enter = function()
    vim.schedule(function()
      require("lualine").refresh()
    end)
  end,
  after_leave = function()
    vim.schedule(function()
      require("lualine").refresh()
    end)
    vim.notify("EXIT CLEVER-F")
  end
}, 
{
  {
    'f<any>',
    function(_, keys, anys)
      return sm.replace_any(keys, anys)
    end,
    {
      desc = 'same as f in normal mode',
    }
  },
  {
    'F<any>',
    function(_, keys, anys)
      return sm.replace_any(keys, anys)
    end,
    {
      desc = 'same as F in normal mode',
    }
  },
  {
    ',',
    ',',
    {
      desc = 'same as , in normal mode',
    }
  },
  {
    ';',
    ';',
    {
      desc = 'same as ; in normal mode',
    }
  },
  {
    'f',
    ';',
    {
      desc = 'same as , in normal mode',
    }
  },
  {
    'F',
    ',',
    {
      desc = 'same as ; in normal mode',
    }
  },
})
vim.keymap.set('n', 'f', function()
  -- サブモードに入った段階でfが入った状態を作る
  sm.enable(sm_clever_f, 'f')
end)
vim.keymap.set('n', 'F', function()
  -- サブモードに入った段階でfが入った状態を作る
  sm.enable(sm_clever_f, 'F')
end)
```
