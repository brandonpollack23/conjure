-- [nfnl] fnl/conjure/client/elixir/iex.fnl
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
config.merge({client = {elixir = {iex = {command = "iex", mix_command = "iex -S mix", prompt_pattern = "iex(%d+)> ", error_pattern = "pry(main)>"}}}})
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
M["buf-suffix"] = ".exs"
M["comment-prefix"] = "# "
M["form-node?"] = function(node)
  log.dbg(("M.form-node?: node:type = " .. a["pr-str"](node:type())))
  log.dbg(("M.form-node?: node:parent = " .. a["pr-str"](node:parent())))
  local parent = node:parent()
  if ("expression_statement" == node:type()) then
    return true
  elseif ("alias_statement" == node:type()) then
    return true
  elseif ("import_statement" == node:type()) then
    return true
  elseif ("module_definition" == node:type()) then
    return true
  elseif ("function_definition" == node:type()) then
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
    local function _12_()
      return ts["add-language"]("elixir")
    end
    if not pcall(_12_) then
      return log.append({(M["comment-prefix"] .. "(error) The elixir client requires a elixir treesitter parser in order to function."), (M["comment-prefix"] .. "(error) See https://github.com/nvim-treesitter/nvim-treesitter"), (M["comment-prefix"] .. "(error) for installation instructions.")})
    else
      local _13_
      if M["is-mix-project?"]() then
        _13_ = cfg({"mix_command"})
      else
        _13_ = cfg({"command"})
      end
      local function _15_()
        return display_repl_status("started")
      end
      local function _16_(err)
        return display_repl_status(err)
      end
      local function _17_(code, signal)
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
      local function _20_(msg)
        return log.dbg(M.unbatch({msg}), {["join-first?"] = true})
      end
      return a.assoc(state(), "repl", stdio.start({["prompt-pattern"] = cfg({"prompt_pattern"}), ["error-pattern"] = cfg({"error_pattern"}), cmd = _13_, ["on-success"] = _15_, ["on-error"] = _16_, ["on-exit"] = _17_, ["on-stray-output"] = _20_}))
    end
  end
end
M["on-exit"] = function()
  return M.stop()
end
M.interrupt = function()
  local function _23_(repl)
    log.append({(M["comment-prefix"] .. " Sending interrupt signal.")}, {["break?"] = true})
    return repl["send-signal"]("sigint")
  end
  return with_repl_or_warn(_23_)
end
M["on-load"] = function()
  if config["get-in"]({"client_on_load"}) then
    return M.start()
  else
    return nil
  end
end
M["on-filetype"] = function()
  local function _25_()
    return M.start()
  end
  mapping.buf("ElixirStart", cfg({"mapping", "start"}), _25_, {desc = "Start the Elixir REPL"})
  local function _26_()
    return M.stop()
  end
  mapping.buf("ElixirStop", cfg({"mapping", "stop"}), _26_, {desc = "Stop the Elixir REPL"})
  local function _27_()
    return M.interrupt()
  end
  return mapping.buf("ElixirInterrupt", cfg({"mapping", "interrupt"}), _27_, {desc = "Interrupt the current evaluation"})
end
return M
