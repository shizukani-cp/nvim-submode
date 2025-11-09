
local Trie = require("lua.nvim-submode.trie")
local Queue = require("lua.nvim-submode.queue")

local M = {}
local crazy_f = {
  {
    'crazy_f',
    'f<any>',
    function(_, keys, anys)
      -- vim.print(keys, anys)
      --
      return M.replace_any(keys, anys)
    end,
    {
      desc = 'same as f in normal mode',
    }
  },
  {
    'crazy_f',
    'g<any><any><any>',
    function(_, keys, anys)
      vim.print(M.replace_any(keys, anys))
      return ""
    end,
    {
      desc = 'same as f in normal mode',
    }
  },
  {
    'crazy_f',
    ',',
    ',',
    {
      desc = 'same as , in normal mode',
    }
  },
  {
    'crazy_f',
    ';',
    ';',
    {
      desc = 'same as ; in normal mode',
    }
  },
}

local clever_f = {
  {
    'clever_f',
    'f',
    ';',
  },
  {
    'clever_f',
    'F',
    ','
  },
  {
    'clever_f',
    'f<any>',
    function(_, _, arg_keys)
      return 'f' .. arg_keys
    end,
  }
}

M.context = {
  -- namespace
  ns = nil,
  -- namespace for input barrier
  barrier_ns = nil,
  -- 既に入力されたキーバインド
  prefix = nil,
  basemode = "normal"


}


function M.regularize_key_input(input)
  local regularized = vim.fn.keytrans(vim.api.nvim_replace_termcodes(input, true, true, true))
  return regularized:gsub("<lt>any>", "<any>"):gsub("<lt>Any>", "<any>")
end

---たとえキー入力を行わない場合であっても、nvimのバグを回避するために空文字列でこの関数を呼び出さなければならない
---@param keys any
function M.input_keys(keys)

  assert(type(keys) == "string", "keys must be string")
  -- This code must works! But dosen's since nvim has a bug!!!!
  -- vim.api.nvim_feedkeys(keys, "n", false)
  vim.api.nvim_feedkeys(keys .. "\\<Ignore>", "ni", false)
end

--- Substitute any to real typed keys. e.g. f<any><any> and you typed "fsa" then the function returns "fsa"
---@param keys string
---@param anys table
---@return string
function M.replace_any(keys, anys)
  for _, typed in ipairs(anys) do
    keys = keys:gsub("<any>", typed, 1)
  end
  return keys
end

local function enable_input_barrier()
  assert(M.context.barrier_ns == nil, "Input barrier has already enabled.")
  M.context.barrier_ns = vim.api.nvim_create_namespace("nvim-submode._internal_input_barrier")
  vim.on_key(function(key, typed)
    -- refuse all keyinput
    return ""
  end, M.context.barrier_ns)
end

local function disable_input_barrier()
  vim.on_key(nil, M.context.barrier_ns)
  M.context.barrier_ns = nil
end

local function get_mode_char()
  local current_mode = vim.api.nvim_get_mode()["mode"]
  local mode_info = current_mode:sub(1, 1)
  mode_info = mode_info == "V" and "v" or mode_info
  return mode_info
end

function M.input_keys_with_input_barrier(keys)
  assert(type(keys) == "string", "keys must be string")
  local mode_info = get_mode_char()
  if (mode_info == "v" or mode_info == "n" or mode_info == "i") then
    -- normalモードではinput barrierに起因する問題を確実に回避するため、normal!コマンドを使う
    if mode_info == "n" or mode_info == "v" then
      vim.cmd("normal! " .. keys .. "<Ignore>")
      --M.input_keys(keys)
    elseif mode_info == "i" then
      if keys == "" then
        return
      end
      -- To empty key queue
      -- HACK: Make empty typeahead buffer if insert mode
      -- This is no effect because all keyinput is refused by barrier
      vim.api.nvim_feedkeys("", "x", false)
      disable_input_barrier()
      vim.api.nvim_feedkeys(keys, "ni", false)
    end
    return
  else
    disable_input_barrier()
    M.input_keys(keys)
    vim.schedule(function()
      enable_input_barrier()
    end)
  end
end

--- @class Submoode
--- @field timeoutlen integer
--- @field default function
--- @field keymap_trie Trie
--- @field name string
---
function M.build_submode(submode_keymaps)
  local keymap_trie = Trie:new()
  local name = submode_keymaps[1][1]
  assert(name ~= "_internal_input_barrier", "This submode name is used intenal. Please rename.")
  for _, sm_keymap in ipairs(submode_keymaps) do
    keymap_trie:insert(M.regularize_key_input(sm_keymap[2]), sm_keymap[3])
  end

  return {
    timeoutlen = vim.o.timeoutlen,
    default = function()

    end,
    keymap_trie = keymap_trie,
    name = name
  }
end

local decideAction

--- Actionを決定する純粋関数
--- @param mode Submoode
--- @param buf string typed buffer queue
--- @param c string typed char but can include "<any>"
--- @param any_substitutes table|nil それぞれの<any>として何が入力されかを表現するリスト
--- @return string rhs rhsとして実際に入力されるキー列。rhsのactionが関数の場合はその関数の返り値。actionを実行しない場合にはnvimのバグを回避するために空文字列を送信する
--- @return string|nil on_key_ret on_key関数の返り値として用いる。nilのときcが基底モードに対してpassthroughされる。nilの場合は遮断(基底モードにcが入力されない)
--- @return string next_buf The next state of the typed buffer queue
--- @return table next_any_substitutes any_substitutesの次の状態
decideAction = function(mode, buf, c, any_substitutes)
  any_substitutes = any_substitutes or {}
  local trie = mode.keymap_trie
  -- 検索用のlhs。<any>を含む
  local search_lhs = buf .. c
  -- 実際のlhs。<any>の代わりに実際の入力に置き換わっている

  local cm = trie:search(search_lhs)
  local pm = trie:countStartsWith(search_lhs)
  if pm == 0 then
    if c == "<any>" then
      print("no lhs exists")
      return "", nil, "", {}
    else
      -- "<any>"で再検索
      table.insert(any_substitutes, c)
      return decideAction(mode, buf, "<any>", any_substitutes)
    end
  elseif cm == true and pm == 1 then
    -- 完全一致のみ。特定のrhsに確定
    local leaf = trie:getLeaf(search_lhs)

    assert(leaf ~= nil)
    assert(leaf.isEndOfWord == true)
    assert(leaf.value ~= nil)

    local action = leaf.value
    local rhs = ""
    if (type(action) == "string") then
      rhs = action
    elseif type(action) == "function" then
      rhs = action(nil, search_lhs, any_substitutes)
    end
    assert(type(rhs) == "string", "Action function must return string! or rhs must be string.")
    return rhs, "", "", {}
  elseif cm == true and pm > 1 then
    assert(false, "timeoutlenを使って分岐する動作を実装する")
  elseif cm == false and pm >= 1 then
    print("Waiting...:" .. search_lhs)

    return "", "", search_lhs, any_substitutes
  end
  assert(false, "Logic Error")
  return "", "", "", {}
end


--- @param mode Submoode
--- @param init_buf string|nil initialized value of buffer
function M.enable(mode, init_buf)
  local ns = vim.api.nvim_create_namespace("nvim-submode." .. mode.name)
  vim.notify("Submode: " .. mode.name)
  -- typed buffer
  local buf = init_buf or ""
  if (init_buf ~= nil) then
    vim.schedule(function()
      -- 事前に入力済みであることを再現するため（これがないとon_keyがトリガーされない）
      M.input_keys("")
    end)
  end
  local callback
  local any_substitutes = {}
  callback = function(k, t)
    enable_input_barrier()
    local typed = vim.fn.keytrans(t)
    local ret, rhs
    print(typed, ":", buf .. typed)
    -- stop key waiting
    vim.on_key(nil, ns)
    if (typed == "<Esc>") then
      if get_mode_char() == "i" then
        -- HACK: Make empty typeahead buffer if insert mode
        -- This is no effect because all keyinput is refused by barrier
        -- abondone <ESC> keymapping in insert mode such as lexima
        -- This is needed for the bug
        vim.api.nvim_feedkeys("<Ignore>", "ix", false)
        disable_input_barrier()
        -- send <Esc> for resetting state
        vim.api.nvim_feedkeys("", "i", false)
        -- move cursor and resume insert
        vim.api.nvim_feedkeys("la", "L", false)
      end
      --vim.notify("Escape: " .. mode.name)
      --vim.on_key(nil, ns)
      M.disable()
      disable_input_barrier()
      return ""
    else
      rhs, ret, buf, any_substitutes = decideAction(mode, buf, typed, any_substitutes)
      M.input_keys_with_input_barrier(rhs)
      vim.schedule(
        function()
          disable_input_barrier()
          vim.on_key(callback, ns)
        end
      )
      -- return ret
    end
    -- TODO: Switch passthrough input
    --return ret
    return ""
  end

  vim.on_key(callback, ns)
  M.context.ns = ns
end

function M.disable()
  if M.context.ns == nil then
    return
  else
    vim.on_key(nil, M.context.ns)
    M.context.ns = nil
    M.context.prefix = nil
  end
end

local sm_crazy_f = M.build_submode(crazy_f)
vim.keymap.set('n', 'f', function()
  M.enable(sm_crazy_f, 'f')
end)

vim.keymap.set('i', 'f', function()
  M.enable(sm_crazy_f, 'f')
end)
-- M.enable(sm_crazy_f)

local fizzbuzz = {
  {
    'fizzbuzz',
    'f',
    function(count, _, _)
      local fb = {}
      for i = 1, count, 1 do
        if i % 15 == 0 then
          table.insert(fb, 'FizzBuzz')
        elseif i % 3 == 0 then
          table.insert(fb, 'Fizz')
        elseif i % 5 == 0 then
          table.insert(fb, 'Buzz')
        end
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, true, fb)

      return ""
    end
  }
}

-- local ns = vim.api.nvim_create_namespace("")
-- local lasttype = nil

-- local innerloop
-- innerloop = function(k, t)
--   vim.on_key(nil, ns)
--   print(k, t)
--   if (vim.fn.keytrans(t) == "<Esc>") then
--     vim.notify("EXIT!!")
--     vim.on_key(nil, ns)
--     return
--   end
--   if t == ";" or t == "," then
--     M.input_keys(t)
--     -- vim.api.nvim_feedkeys(t .. "\\<Ignore>", "ni", false)
--     vim.notify(";,or")
--     vim.schedule(function()
--       vim.on_key(innerloop, ns)
--     end)
--     return ""
--   end
--   if lasttype ~= nil then
--     M.input_keys(lasttype .. t)
--     -- vim.api.nvim_feedkeys(lasttype .. vim.fn.keytrans(t) .. "\\<Ignore>", "ni", false)
--     lasttype = nil
--   elseif t == "f" or t == "F" then
--     lasttype = t
--   end
--   vim.schedule(
--     function()
--       vim.on_key(innerloop, ns)
--     end
--   )
-- end

-- vim.on_key(innerloop, ns)
-- crazy-f-mode
-- hhhhhhjjjjjjkkkkkkhkkkkhkkkhlkkkkkkkkh



vim.keymap.set('n', ';', function()
  vim.notify("; is nop")
end)
vim.keymap.set('n', ',', function()
  vim.notify(", is nop")
end)

vim.keymap.set('i', ';', function()
  vim.cmd('normal! hjkl')
end)
vim.keymap.set('v', ';', function()
  vim.cmd('normal! k')
end)

return M
