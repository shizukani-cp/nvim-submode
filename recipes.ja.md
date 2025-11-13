# レシピ
## CapsLockサブモード

CapsLockサブモードではアルファベットがすべて大文字になります。insertモードでの利用を想定しているため、insertモードのキーマップを起動用に割り当ててください。
`<any>`は任意の１文字のキーにマッチすることを意味します。このモードではカウント機能は不要であるため、オフにしてあります。action関数(サブモードのrhsに割り当てる関数)の1つ目の返り値では実際にnvimに送信される文字列を設定します。また、2つ目の返り値に`sm.EXIT_SUBMODE`を設定することでキーバインドを実行後にサブモードを終了できます。`<Esc>`を押すことでもサブモードを終了できます。この例ではサブモードのトリガーとして`<C-l>`を設定しています。

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

## Clever-Fサブモード

Clever-Fサブモードでは[clever-f.vim](https://github.com/rhysd/clever-f.vim)を簡易的に再現します。`f<any>`,`F<any>`でデフォルトのNeovimのf/Fと同様の挙動になります。一方`f/F`単独ではそれぞれ`;/,`と同じ（直前の検索結果と同じ文字を順/逆方向に探す）という挙動になります。また、`;/,`もデフォルトと同様にセットアップされます。countによる操作の繰り返しにも対応しています。`sm.enable`は2番目の引数で「サブモード開始時のバッファの中身」を指定できます。今回のケースでは`f`,`F`を入力されたされた状態を再現し、サブモード開始と検索を同時に開始します。

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
