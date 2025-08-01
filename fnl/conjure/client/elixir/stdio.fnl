(local {: autoload : define} (require :conjure.nfnl.module))
(local a (autoload :conjure.aniseed.core))
(local str (autoload :conjure.aniseed.string))
(local stdio (autoload :conjure.remote.stdio))
(local config (autoload :conjure.config))
(local mapping (autoload :conjure.mapping))
(local client (autoload :conjure.client))
(local log (autoload :conjure.log))
(local ts (autoload :conjure.tree-sitter))

(local M (define :conjure.client.elixir.iex))

(config.merge
  {:client
   {:elixir
    {:iex
     {:command "iex"
      :mix_command "iex -S mix"
      :prompt_pattern "iex%(%d+%)> "
      }}}})

(when (config.get-in [:mapping :enable_defaults])
  (config.merge
    {:client
     {:elixir
      {:iex
       {:mapping {:start "cs"
                  :stop "cS"
                  :interrupt "ei"}}}}}))

(local cfg (config.get-in-fn [:client :elixir :iex]))
(local state (client.new-state #(do {:repl nil})))
(set M.buf-suffix ".ex")
(set M.comment-prefix "# ")

(fn M.form-node? [node]
  (log.dbg (.. "M.form-node?: node:type = " (a.pr-str (node:type))))
  (log.dbg (.. "M.form-node?: node:parent = " (a.pr-str (node:parent))))
  (let [parent (node:parent)]
    (if (= "call" (node:type)) true
        (= "binary_operator" (node:type)) true
        (= "integer" (node:type)) true
        (= "char" (node:type)) true
        (= "sigil" (node:type)) true
        (= "float" (node:type)) true
        (= "string" (node:type)) true
        (= "atom" (node:type)) true
        false)))

(fn with-repl-or-warn [f opts]
  (let [repl (state :repl)]
    (if repl
      (f repl)
      (log.append [(.. M.comment-prefix "No REPL running")
                   (.. M.comment-prefix
                       "Start REPL with "
                       (config.get-in [:mapping :prefix])
                       (cfg [:mapping :start]))]))))

(fn prep-code [s]
  (.. s "\n"))

(fn M.unbatch [msgs]
  (->> msgs
       (a.map #(or (a.get $1 :out) (a.get $1 :err)))
       (str.join "")))

(fn log-repl-output [msgs]
  (let [msgs (-> msgs M.unbatch)]
    (log.append [msgs])))

(fn M.eval-str [opts]
  (log.dbg (.. "M.eval-str opts >> " (a.pr-str opts) "<<"))
  (with-repl-or-warn
    (fn [repl]
      (repl.send
        opts.code
        (fn [msgs]
          (log-repl-output msgs)
          (when opts.on-result
            (let [msgs (-> msgs M.unbatch)]
              (opts.on-result msgs))))
        {:batch? true}))))

(fn M.eval-file [opts]
  (M.eval-str (a.assoc opts :code (a.slurp opts.file-path))))

(fn display-repl-status [status]
  (log.append
    [(.. M.comment-prefix
         (cfg [:command])
         " (" (or status "no status") ")")]
    {:break? true}))

(fn display-result [msg]
  (->> msg
       (a.map #(.. M.comment-prefix $1))
       log.append))

(fn format-msg [msg]
  (->> (str.split msg "\n")
       (a.filter #(not (= "" $1)))
       (a.filter #(not (= "()" $1)))))

(fn M.stop []
  (let [repl (state :repl)]
    (when repl
      (repl.destroy)
      (display-repl-status :stopped)
      (a.assoc (state) :repl nil))))

(fn M.is-mix-project? []
  (let [cwd (vim.fn.getcwd)
        mix_file (io.open (.. cwd "/mix.exs"))]
    (if mix_file
      (do
        (mix_file:close)
        true)
      false)))

(fn M.start []
  (log.append [(.. M.comment-prefix "Starting Elixir client...")])
  (if (state :repl)
    (log.append [(.. M.comment-prefix "Can't start, REPL is already running.")
                 (.. M.comment-prefix "Stop the REPL with "
                     (config.get-in [:mapping :prefix])
                     (cfg [:mapping :stop]))]
                {:break? true})
    (if (not (pcall #(ts.add-language "elixir")))
      (log.append [(.. M.comment-prefix "(error) The elixir client requires a elixir treesitter parser in order to function.")
                   (.. M.comment-prefix "(error) See https://github.com/nvim-treesitter/nvim-treesitter")
                   (.. M.comment-prefix "(error) for installation instructions.")])
      (a.assoc
        (state) :repl
        (stdio.start
          {:prompt-pattern (cfg [:prompt_pattern])
           :cmd (if (M.is-mix-project?)
                  (do  
                    (log.append [(.. M.comment-prefix "Using iex mix mode")])
                    (cfg [:mix_command]))
                  (do  
                    (log.append [(.. M.comment-prefix "Using iex standalone mode")]) 
                    (cfg [:command])))

         :on-success
         (fn []
           (display-repl-status :started)
           (with-repl-or-warn
             (fn [repl]
               (repl.send
                 (prep-code ":help")
                 (fn [msgs]
                   (display-result (-> msgs M.unbatch format-msg)))
                 {:batch? true}))))

         :on-error
         (fn [err]
           (log.append ["error"])
           (display-repl-status err))

         :on-exit
         (fn [code signal]
           (when (and (= :number (type code)) (> code 0))
             (log.append [(.. M.comment-prefix "process exited with code " code)]))
           (when (and (= :number (type signal)) (> signal 0))
             (log.append [(.. M.comment-prefix "process exited with signal " signal)]))
           (M.stop))

         :on-stray-output
         (fn [msg]
           (log.dbg (-> [msg] M.unbatch) {:join-first? true}))})))))

(fn M.on-exit []
  (M.stop))

(fn M.interrupt []
  (with-repl-or-warn
    (fn [repl]
      (log.append [(.. M.comment-prefix " Sending interrupt signal.")] {:break? true})
      (repl.send-signal :sigint))))

(fn M.on-load []
  (when (config.get-in [:client_on_load])
    (M.start)))

(fn M.on-filetype []
  (mapping.buf
    :ElixirStart (cfg [:mapping :start])
    #(M.start)
    {:desc "Start the Elixir REPL"})

  (mapping.buf
    :ElixirStop (cfg [:mapping :stop])
    #(M.stop)
    {:desc "Stop the Elixir REPL"})

  (mapping.buf
    :ElixirInterrupt (cfg [:mapping :interrupt])
    #(M.interrupt)
    {:desc "Interrupt the current evaluation"}))

M
