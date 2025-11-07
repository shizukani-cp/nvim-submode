local M = {}
local crazy_f = {
  {
    'crazy_f',
    'f<any>',
    function(_, _, arg_keys)
      return 'f' .. arg_keys
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
  -- 既に入力されたキーバインド
  prefix = nil,


}



function M.enable(mode)
  local ns = vim.api.nvim_create_namespace("nvim-submode." .. mode.name)
  vim.on_key(function(key, typed)

  end, ns)
  M.context.ns = ns
end

function M.disable()
  if M.context.ns == nil then
    return
  else
    vim.on_key(nil, M.context.ns)
    vim.api.nvim_input(sendkey)
    M.context.ns = nil
    M.context.prefix = nil
  end
end

function M.input_keys(keys)
  vim.api.nvim_feedkeys(keys .. "\\<Ignore>", "ni", false)
end

local fizzbuzz = {
  {
    'fizzbuzz',
    'f',
    function(count, _, _)
      local fb = ''
      for i = 1, count, 1 do
        if i % 15 == 0 then
          fb = fb .. 'FizzBuzz\n'
        elseif i % 3 == 0 then
          fb = fb .. 'Fizz\n'
        elseif i % 5 == 0 then
          fb = fb .. 'Buzz\n'
        end
      end
      return fb
    end
  }
}

local ns = vim.api.nvim_create_namespace("")
local lasttype = nil
local findkey = nil

local innerloop
innerloop = function(k, t)
  vim.on_key(nil, ns)
  print(k, t)
  if (vim.fn.keytrans(t) == "<Esc>") then
    vim.notify("EXIT!!")
    vim.on_key(nil, ns)
    return
  end
  if t == ";" or t == "," then
    M.input_keys(t)
    -- vim.api.nvim_feedkeys(t .. "\\<Ignore>", "ni", false)
    vim.notify(";,or")
    vim.schedule(function()
      vim.on_key(innerloop, ns)
    end)
    return ""
  end
  if lasttype ~= nil then
    M.input_keys(lasttype .. t)
    -- vim.api.nvim_feedkeys(lasttype .. vim.fn.keytrans(t) .. "\\<Ignore>", "ni", false)
    lasttype = nil
  elseif t == "f" or t == "F" then
    lasttype = t
  end
  vim.schedule(
    function()
      vim.on_key(innerloop, ns)
    end
  )
end

vim.on_key(innerloop, ns)
-- crazy-f-mode
-- hhhhhhjjjjjjkkkkkkhkkkkhkkkhlkkkkkkkkh


vim.keymap.set('n', ';', function()
end)
vim.keymap.set('n', ',', function()

end)


vim.keymap.set('n', ';', function()
  vim.notify("; is nop")
end)
vim.keymap.set('n', ',', function()
  vim.notify(", is nop")
end)

return M
