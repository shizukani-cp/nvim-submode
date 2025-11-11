local Trie = require("lua.nvim-submode.trie")
local Queue = require("lua.nvim-submode.queue")
local DEBUG = true
local function debugPrint(...)
  if DEBUG == true then
    print(...)
  end
end

local SUBMODE_COUNT_DISABLE = -1

local M = {}
local crazy_f = {
  {
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
    'g<any><any><any>',
    function(count, keys, anys)
      vim.print(M.replace_any(keys, anys))
      return "gggg" .. tostring(count)
    end,
    {
      desc = 'same as f in normal mode',
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
}

local clever_f = {
  {
    'f',
    ';',
  },
  {
    'F',
    ','
  },
  {
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


}


function M.regularize_key_input(input)
  local regularized = vim.fn.keytrans(vim.api.nvim_replace_termcodes(input, true, true, true))
  return regularized:gsub("<lt>any>", "<any>"):gsub("<lt>Any>", "<any>")
end

local function is_number_str(c)
  return tonumber(c) ~= nil
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

local function disable_input_barrier()
  debugPrint("DISABLE barrier")
  vim.on_key(nil, M.context.barrier_ns)
  M.context.barrier_ns = nil
end

local function enable_input_barrier()
  debugPrint("ENABLE barrier")
  --assert(M.context.barrier_ns == nil, "Input barrier has already enabled.")
  if M.context.barrier_ns ~= nil then
    disable_input_barrier()
  end
  M.context.barrier_ns = vim.api.nvim_create_namespace("nvim-submode._internal_input_barrier")
  vim.on_key(function(key, typed)
    -- debugPrint("barrier >> k:" .. vim.fn.keytrans(key) .. " t:" .. vim.fn.keytrans(typed))
    -- refuse all keyinput
    return ""
  end, M.context.barrier_ns)
end



local function get_mode_char()
  local current_mode = vim.api.nvim_get_mode()["mode"]
  local mode_info = current_mode:sub(1, 1)
  mode_info = mode_info == "V" and "v" or mode_info
  return mode_info
end

function M.input_keys_with_input_barrier(keys)
  if (type(keys) ~= "string" or keys == "") then
    return
  end
  assert(type(keys) == "string", "keys must be string")
  local mode_info = get_mode_char()
  if (mode_info == "v" or mode_info == "n" or mode_info == "i") then
    -- normalモードではinput barrierに起因する問題を確実に回避するため、normal!コマンドを使う
    if mode_info == "n" or mode_info == "v" then
      vim.cmd("normal! " .. vim.api.nvim_replace_termcodes(keys, true, true, true) .. "")
      --M.input_keys(keys)
    elseif mode_info == "i" then
      if keys == "" then
        return
      end
      -- バリアを避けるためにペーストする
      vim.api.nvim_paste(keys, false, -1)
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


--- @class SubmodeMetadata
--- @field name string The name of submode
--- @field display_name string|nil The name of the submode displayed in the status line.
--- @field after_enter function|nil A callback that is triggered after the sub-mode is enabled.
--- @field after_leave function|nil A callback that is triggered after the submode is disable.
--- @field timeoutlen number|nil The waiting time before ending the partial match waiting period and executing the exact match, when both exact and partial key mappings exist. Same as g:timeoutlen


---Build submode instance from SubmodeMetadata and submode keymaps.
---@param submode_metadata SubmodeMetadata
---@param submode_keymaps table
---@return Submoode
function M.build_submode(submode_metadata, submode_keymaps)
  local keymap_trie = Trie:new()
  local name = submode_metadata.name
  assert(name ~= "_internal_input_barrier", "This submode name is used intenal. Please rename.")
  for _, sm_keymap in ipairs(submode_keymaps) do
    keymap_trie:insert(M.regularize_key_input(sm_keymap[1]), sm_keymap[2])
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
--- @param submode_count number same as v:count, which represents number modification to keymap.
--- @return string rhs rhsとして実際に入力されるキー列。rhsのactionが関数の場合はその関数の返り値。actionを実行しない場合にはnvimのバグを回避するために空文字列を送信する
--- @return string|nil on_key_ret on_key関数の返り値として用いる。nilのときcが基底モードに対してpassthroughされる。nilの場合は遮断(基底モードにcが入力されない)
--- @return string next_buf The next state of the typed buffer queue
--- @return table next_any_substitutes any_substitutesの次の状態
--- @return boolean timer_start timerを起動するかどうかを表す。曖昧なキー入力時に使われる
decideAction = function(mode, buf, c, any_substitutes, submode_count)
  any_substitutes = any_substitutes or {}
  local trie = mode.keymap_trie
  -- 検索用のlhs。<any>を含む
  local search_lhs = buf .. c
  -- 実際のlhs。<any>の代わりに実際の入力に置き換わっている
  local cm = trie:search(search_lhs)
  local pm = trie:countStartsWith(search_lhs)
  if (submode_count ~= SUBMODE_COUNT_DISABLE and is_number_str(c)) then
    -- キー入力の途中で数字を打ったことになるが、この操作はカウントが有効な場合は許可されていないので、問答無用でマッチング失敗
    debugPrint("Number is not interpreted as key if submode enable.")
    return "", nil, "", {}, false
  end
  if pm == 0 then
    if c == "<any>" then
      debugPrint("no lhs exists")
      return "", nil, "", {}, false
    else
      -- "<any>"で再検索
      table.insert(any_substitutes, c)
      return decideAction(mode, buf, "<any>", any_substitutes, submode_count)
    end
  elseif cm == true and pm == 1 then
    -- 完全一致のみ。特定のrhsに確定
    local leaf = trie:getLeaf(search_lhs)

    assert(leaf ~= nil)
    assert(leaf.isEndOfWord == true)
    assert(leaf.value ~= nil)

    local action = leaf.value
    local rhs = ""
    local rhc_callback = function()
      local rhs = ""
      if (type(action) == "string") then
        if (submode_count > 0) then
          -- submode_count回、キーマッピングを繰り返す
          rhs = action:rep(submode_count)
        else
          rhs = action
        end
      elseif type(action) == "function" then
        rhs = action(submode_count, search_lhs, any_substitutes)
      end
      return rhs
    end
    if (type(action) == "string") then
      if (submode_count > 0) then
        -- submode_count回、キーマッピングを繰り返す
        rhs = action:rep(submode_count)
      else
        rhs = action
      end
    elseif type(action) == "function" then
      rhs = action(submode_count, search_lhs, any_substitutes)
    end
    assert(type(rhs) == "string", "Action function must return string! or rhs must be string.")
    return rhs, "", "", {}, false
  elseif cm == true and pm > 1 then
    assert(false, "timeoutlenを使って分岐する動作を実装する")
  elseif cm == false and pm >= 1 then
    debugPrint("Waiting...:" .. search_lhs)

    return "", "", search_lhs, any_substitutes, false
  end
  assert(false, "Logic Error")
  return "", "", "", {}, false
end



local function init_submode(modename)
  -- 現在のstatuslineの内容を保存する関数
  -- 1. 現在のstatuslineの内容を取得し、変数に保存
  local original_statusline = vim.o.statusline

  -- 2. 新しいテキストでstatuslineを書き換え
  -- %#StatusLine#はハイライトグループで、デフォルトのstatuslineのスタイルを適用します。
  vim.o.statusline = '%#StatusLine# ' .. modename .. ' '

  -- 3. statuslineを再描画
  vim.schedule(function()
    vim.cmd('redrawstatus')
  end)


  -- 4. statuslineを元に戻す関数を返す
  return function()
    -- 元のstatuslineの内容を復元
    vim.o.statusline = original_statusline

    -- statuslineを再描画
    vim.cmd('redrawstatus')
  end
end

--- @param mode Submoode
--- @param init_buf string|nil initialized value of buffer
function M.enable(mode, init_buf)
  local ns = vim.api.nvim_create_namespace("nvim-submode." .. mode.name)
  M.restore_statusline = init_submode(mode.name)


  vim.notify("Submode: " .. mode.name)
  -- typed buffer
  local buf = init_buf or ""
  if (init_buf ~= nil) then
    vim.schedule(function()
      -- 事前に入力済みであることを再現するため（これがないとon_keyがトリガーされない）
      M.input_keys("")
    end)
  end
  local is_submode_count = true
  local callback
  local any_substitutes = {}
  local prev_t = ""
  local num_queue = Queue:new()
  -- 現在判定中のキーマッピングに対して適用予定のcount, -1であるときカウント機能が無効であることを示す
  local count_reg = nil
  callback = function(k, t)
    local typed = vim.fn.keytrans(t)
    debugPrint("k:" .. vim.fn.keytrans(k) .. " t:" .. vim.fn.keytrans(t))
    if not is_number_str(prev_t) and is_number_str(typed) and count_reg == nil then
      -- Switch input_char from text to number
      debugPrint("Enqueue:", typed)
      num_queue:enqueue("")
    end
    enable_input_barrier()
    vim.on_key(nil, ns)
    local is_t_empty = t == ""
    t = is_t_empty and prev_t or t
    prev_t = t

    local ret, rhs
    debugPrint(buf .. typed, "<-", typed)
    -- stop key waiting

    if (typed == "<Esc>") then
      -- If there are keybindings associated with <Esc>,
      -- it's necessary to wait until the consumption of their right-hand sides is complete before exiting the submode,
      -- so we use vim.schedule to wait until the processing is finished.
      vim.notify("EXIT")
      M.restore_statusline()
      vim.schedule(function()
        M.disable()
        disable_input_barrier()
      end)
      return ""
    else
      -- If t is empty, meaning that unnecessary rhs input is being provided due to the user's mapping,
      -- it should always return an empty string and be ignored.
      if is_t_empty then
        debugPrint("DISGARD:", k)
        vim.schedule(
          function()
            disable_input_barrier()
            vim.on_key(callback, ns)
          end
        )
        return ""
      end

      -- count_regがnilではないということは何かしらを入力途中であることを意味する
      if is_submode_count and is_number_str(typed) and count_reg == nil then
        debugPrint("Before:", num_queue:getBack())
        local current_end_of_num_queue = num_queue:getBack()
        debugPrint("count:", num_queue:getBack())
        debugPrint("length:", num_queue:size())
        num_queue:setBack(current_end_of_num_queue .. typed)
        debugPrint("Next:", num_queue:getBack())
        vim.schedule(function()
          disable_input_barrier()
          vim.on_key(callback, ns)
        end)
        return ""
      end
      num_queue:show()
      -- レジスタに値がない場合のみ更新する
      if count_reg == nil then
        if is_submode_count then
          if num_queue:isEmpty() then
            count_reg = 0
          else
            -- -2 represents the error queue has not number
            count_reg = tonumber(num_queue:dequeue()) or -2
          end
        else
          count_reg = SUBMODE_COUNT_DISABLE
        end
      end
      debugPrint("NOT DISGARD", typed, k)
      local ok
      ok, rhs, ret, buf, any_substitutes = pcall(decideAction, mode, buf, typed, any_substitutes, count_reg)
      if (not ok) then
        disable_input_barrier()
        vim.notify("ERROR: " .. rhs, vim.log.levels.ERROR)
        return
      end

      if buf == "" then
        -- 実際にキーマップが実行されるか、キーマップがキャンセルされた場合のみレジスタをリセットする
        count_reg = nil
      end
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
  end
end

local sm_crazy_f = M.build_submode({
  name = "CRAZY-F"
}, crazy_f)
vim.keymap.set('n', 'f', function()
  M.enable(sm_crazy_f, 'f')
end)
-- M.enable(sm_crazy_f)
vim.keymap.set('i', 'f', function()
  M.enable(sm_crazy_f, 'f')
end)



-- コマンドラインモード (c) で <C-y> (Ctrl+Y) を押した時の動作を設定
vim.keymap.set('c', '<C-y>', function()
  vim.cmd("normal! :echo")
end, { desc = "Process command line" })
-- M.enable(sm_crazy_f)

local fizzbuzz = {
  {
    'f',
    function(count, _, _)
      assert(type(count) == "number", "count must be number.")
      if (type(count) ~= "number") then
        return "ERROR:" .. type(count)
      end
      count = count > 0 and count or 1
      local fb = ""
      for i = 1, count, 1 do
        if i % 15 == 0 then
          fb = fb .. 'FizzBuzz' .. '\n'
        elseif i % 3 == 0 then
          fb = fb .. 'Fizz' .. '\n'
        elseif i % 5 == 0 then
          fb = fb .. 'Buzz' .. '\n'
        else
          fb = fb .. tostring(i) .. '\n'
        end
      end

      return fb
    end
  }
}


vim.keymap.set('i', '*', function()
  M.enable(M.build_submode({
    name = "FIZZBUZZ"
  }, fizzbuzz))
end)

local window_sm_map = {
  {
    '+',
    '<C-W>>',
    {}
  },
  {
    '-',
    '<C-W><',
    {}
  }
}

vim.keymap.set('n', 'www', function()
  M.enable(M.build_submode({
    name = "WINDOW"
  }, window_sm_map))
end)



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
