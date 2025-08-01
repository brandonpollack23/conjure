-- [nfnl] fnl/conjure/client/elixir/stdio.fnl
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_["autoload"]
local define = _local_1_["define"]
local a = autoload("conjure.aniseed.core")
local str = autoload("conjure.aniseed.string")
local stdio = autoload("conjure.remote.stdio")
local config = autoload("conjure.config")
local mapping = autoload("conjure.mapping")
local client = autoload("conjure.client")
local log = autoload("conjure.log")
local ts = autoload("conjure.tree-sitter")
local M = define("conjure.client.elixir.iex")
config.merge({client = {elixir = {iex = {command = "iex", mix_command = "iex -S mix", prompt_pattern = "iex%(%d+%)> "}}}})
if config["get-in"]({"mapping", "enable_defaults"}) then
  config.merge({client = {elixir = {iex = {mapping = {start = "cs", stop = "cS", interrupt = "ei"}}}}})
else
end
local cfg = config["get-in-fn"]({"client", "elixir", "iex"})
local state
local function _3_()
  return {repl = nil}
end
state = client["new-state"](_3_)
M["buf-suffix"] = ".ex"
M["comment-prefix"] = "# "
M["form-node?"] = function(node)
  log.dbg(("M.form-node?: node:type = " .. a["pr-str"](node:type())))
  log.dbg(("M.form-node?: node:parent = " .. a["pr-str"](node:parent())))
  local parent = node:parent()
  if ("call" == node:type()) then
    return true
  elseif ("binary_operator" == node:type()) then
    return true
  elseif ("integer" == node:type()) then
    return true
  elseif ("char" == node:type()) then
    return true
  elseif ("sigil" == node:type()) then
    return true
  elseif ("float" == node:type()) then
    return true
  elseif ("string" == node:type()) then
    return true
  elseif ("atom" == node:type()) then
    return true
  else
    return false
  end
end
local function with_repl_or_warn(f, opts)
  local repl = state("repl")
  if repl then
    return f(repl)
  else
    return log.append({(M["comment-prefix"] .. "No REPL running"), (M["comment-prefix"] .. "Start REPL with " .. config["get-in"]({"mapping", "prefix"}) .. cfg({"mapping", "start"}))})
  end
end
local function prep_code(s)
  return (s .. "\n")
end
M.unbatch = function(msgs)
  local function _6_(_241)
    return (a.get(_241, "out") or a.get(_241, "err"))
  end
  return str.join("", a.map(_6_, msgs))
end
local function log_repl_output(msgs)
  local msgs0 = M.unbatch(msgs)
  return log.append({msgs0})
end
M["eval-str"] = function(opts)
  log.dbg(("M.eval-str opts >> " .. a["pr-str"](opts) .. "<<"))
  local function _7_(repl)
    local function _8_(msgs)
      log_repl_output(msgs)
      if opts["on-result"] then
        local msgs0 = M.unbatch(msgs)
        return opts["on-result"](msgs0)
      else
        return nil
      end
    end
    return repl.send(opts.code, _8_, {["batch?"] = true})
  end
  return with_repl_or_warn(_7_)
end
M["eval-file"] = function(opts)
  return M["eval-str"](a.assoc(opts, "code", a.slurp(opts["file-path"])))
end
local function display_repl_status(status)
  return log.append({(M["comment-prefix"] .. cfg({"command"}) .. " (" .. (status or "no status") .. ")")}, {["break?"] = true})
end
local function display_result(msg)
  local function _10_(_241)
    return (M["comment-prefix"] .. _241)
  end
  return log.append(a.map(_10_, msg))
end
local function format_msg(msg)
  local function _11_(_241)
    return not ("()" == _241)
  end
  local function _12_(_241)
    return not ("" == _241)
  end
  return a.filter(_11_, a.filter(_12_, str.split(msg, "\n")))
end
M.stop = function()
  local repl = state("repl")
  if repl then
    repl.destroy()
    display_repl_status("stopped")
    return a.assoc(state(), "repl", nil)
  else
    return nil
  end
end
M["is-mix-project?"] = function()
  local cwd = vim.fn.getcwd()
  local mix_file = io.open((cwd .. "/mix.exs"))
  if mix_file then
    mix_file:close()
    return true
  else
    return false
  end
end
M.start = function()
  log.append({(M["comment-prefix"] .. "Starting Elixir client...")})
  if state("repl") then
    return log.append({(M["comment-prefix"] .. "Can't start, REPL is already running."), (M["comment-prefix"] .. "Stop the REPL with " .. config["get-in"]({"mapping", "prefix"}) .. cfg({"mapping", "stop"}))}, {["break?"] = true})
  else
    local function _15_()
      return ts["add-language"]("elixir")
    end
    if not pcall(_15_) then
      return log.append({(M["comment-prefix"] .. "(error) The elixir client requires a elixir treesitter parser in order to function."), (M["comment-prefix"] .. "(error) See https://github.com/nvim-treesitter/nvim-treesitter"), (M["comment-prefix"] .. "(error) for installation instructions.")})
    else
      local _16_
      if M["is-mix-project?"]() then
        log.append({(M["comment-prefix"] .. "Using iex mix mode")})
        _16_ = cfg({"mix_command"})
      else
        log.append({(M["comment-prefix"] .. "Using iex standalone mode")})
        _16_ = cfg({"command"})
      end
      local function _18_()
        display_repl_status("started")
        local function _19_(repl)
          local function _20_(msgs)
            return display_result(format_msg(M.unbatch(msgs)))
          end
          return repl.send(prep_code(":help"), _20_, {["batch?"] = true})
        end
        return with_repl_or_warn(_19_)
      end
      local function _21_(err)
        log.append({"error"})
        return display_repl_status(err)
      end
      local function _22_(code, signal)
        if (("number" == type(code)) and (code > 0)) then
          log.append({(M["comment-prefix"] .. "process exited with code " .. code)})
        else
        end
        if (("number" == type(signal)) and (signal > 0)) then
          log.append({(M["comment-prefix"] .. "process exited with signal " .. signal)})
        else
        end
        return M.stop()
      end
      local function _25_(msg)
        return log.dbg(M.unbatch({msg}), {["join-first?"] = true})
      end
      return a.assoc(state(), "repl", stdio.start({["prompt-pattern"] = cfg({"prompt_pattern"}), cmd = _16_, ["on-success"] = _18_, ["on-error"] = _21_, ["on-exit"] = _22_, ["on-stray-output"] = _25_}))
    end
  end
end
M["on-exit"] = function()
  return M.stop()
end
M.interrupt = function()
  local function _28_(repl)
    log.append({(M["comment-prefix"] .. " Sending interrupt signal.")}, {["break?"] = true})
    return repl["send-signal"]("sigint")
  end
  return with_repl_or_warn(_28_)
end
M["on-load"] = function()
  if config["get-in"]({"client_on_load"}) then
    return M.start()
  else
    return nil
  end
end
M["on-filetype"] = function()
  local function _30_()
    return M.start()
  end
  mapping.buf("ElixirStart", cfg({"mapping", "start"}), _30_, {desc = "Start the Elixir REPL"})
  local function _31_()
    return M.stop()
  end
  mapping.buf("ElixirStop", cfg({"mapping", "stop"}), _31_, {desc = "Stop the Elixir REPL"})
  local function _32_()
    return M.interrupt()
  end
  return mapping.buf("ElixirInterrupt", cfg({"mapping", "interrupt"}), _32_, {desc = "Interrupt the current evaluation"})
end
return M
