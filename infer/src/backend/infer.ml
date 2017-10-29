(*
 * Copyright (c) 2016 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd

(** Top-level driver that orchestrates build system integration, frontends, backend, and
    reporting *)

module CLOpt = CommandLineOption
module L = Logging
module F = Format

let run driver_mode =
  let open Driver in
  run_prologue driver_mode ;
  let changed_files = read_config_changed_files () in
  capture driver_mode ~changed_files ;
  analyze_and_report driver_mode ~changed_files ;
  run_epilogue driver_mode


let setup () =
  match Config.command with
  | Analyze ->
      ResultsDir.assert_results_dir "have you run capture before?"
  | Report | ReportDiff ->
      ResultsDir.create_results_dir ()
  | Diff ->
      ResultsDir.remove_results_dir () ; ResultsDir.create_results_dir ()
  | Capture | Compile | Run ->
      let driver_mode = Lazy.force Driver.mode_from_command_line in
      if not
           ( Driver.(equal_mode driver_mode Analyze)
           ||
           Config.(buck || continue_capture || infer_is_clang || infer_is_javac || reactive_mode) )
      then ResultsDir.remove_results_dir () ;
      ResultsDir.create_results_dir ()
  | Explore ->
      ResultsDir.assert_results_dir "please run an infer analysis first"


let print_active_checkers () =
  (if Config.print_active_checkers && CLOpt.is_originator then L.result else L.environment_info)
    "Analyzer: %s@."
    Config.(string_of_analyzer analyzer) ;
  (if Config.print_active_checkers && CLOpt.is_originator then L.result else L.environment_info)
    "Active checkers: %a@."
    (Pp.seq ~sep:", " RegisterCheckers.pp_checker)
    (RegisterCheckers.get_active_checkers ())


let log_environment_info () =
  L.environment_info "CWD = %s@\n" (Sys.getcwd ()) ;
  ( match Config.inferconfig_file with
  | Some file ->
      L.environment_info "Read configuration in %s@\n" file
  | None ->
      L.environment_info "No .inferconfig file found@\n" ) ;
  L.environment_info "Project root = %s@\n" Config.project_root ;
  let infer_args =
    Sys.getenv CLOpt.args_env_var |> Option.map ~f:(String.split ~on:CLOpt.env_var_sep)
    |> Option.value ~default:["<not set>"]
  in
  L.environment_info "INFER_ARGS = %a" Pp.cli_args infer_args ;
  L.environment_info "command line arguments: %a" Pp.cli_args (Array.to_list Sys.argv) ;
  print_active_checkers ()


let () =
  ( if Config.linters_validate_syntax_only then
      match CTLParserHelper.validate_al_files () with
      | Ok () ->
          L.exit 0
      | Error e ->
          print_endline e ; L.exit 3 ) ;
  if Config.print_builtins then Builtin.print_and_exit () ;
  setup () ;
  log_environment_info () ;
  if Config.debug_mode && CLOpt.is_originator then
    L.progress "Logs in %s@." (Config.results_dir ^/ Config.log_file) ;
  match Config.command with
  | Analyze ->
      let pp_cluster_opt fmt = function
        | None ->
            F.fprintf fmt "(no cluster)"
        | Some cluster ->
            F.fprintf fmt "of cluster %s" (Filename.basename cluster)
      in
      L.environment_info "Starting analysis %a" pp_cluster_opt Config.cluster_cmdline ;
      if Config.developer_mode then InferAnalyze.register_perf_stats_report () ;
      Driver.analyze_and_report Analyze ~changed_files:(Driver.read_config_changed_files ())
  | Report ->
      InferPrint.main ~report_csv:Config.issues_csv ~report_json:None
  | ReportDiff ->
      (* at least one report must be passed in input to compute differential *)
      ( match (Config.report_current, Config.report_previous) with
      | None, None ->
          L.(die UserError)
            "Expected at least one argument among 'report-current' and 'report-previous'"
      | _ ->
          () ) ;
      ReportDiff.reportdiff ~current_report:Config.report_current
        ~previous_report:Config.report_previous
  | Capture | Compile | Run ->
      run (Lazy.force Driver.mode_from_command_line)
  | Diff ->
      Diff.diff (Lazy.force Driver.mode_from_command_line)
  | Explore ->
      let if_some key opt args =
        match opt with None -> args | Some arg -> key :: string_of_int arg :: args
      in
      let if_true key opt args = if not opt then args else key :: args in
      let if_false key opt args = if opt then args else key :: args in
      let args =
        if_some "--max-level" Config.max_nesting @@ if_true "--only-show" Config.only_show
        @@ if_false "--no-source" Config.source_preview @@ if_true "--html" Config.html
        @@ if_some "--select" Config.select ["-o"; Config.results_dir]
      in
      let prog = Config.lib_dir ^/ "python" ^/ "inferTraceBugs" in
      if is_error (Unix.waitpid (Unix.fork_exec ~prog ~argv:(prog :: args) ())) then
        L.external_error
          "** Error running the reporting script:@\n**   %s %s@\n** See error above@." prog
          (String.concat ~sep:" " args)

