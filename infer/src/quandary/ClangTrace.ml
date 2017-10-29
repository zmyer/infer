(*
 * Copyright (c) 2016 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd
module F = Format
module L = Logging

module SourceKind = struct
  type t =
    | CommandLineFlag of Var.t  (** source that was read from a command line flag *)
    | Endpoint of (Mangled.t * Typ.desc)  (** source originating from formal of an endpoint *)
    | EnvironmentVariable  (** source that was read from an environment variable *)
    | File  (** source that was read from a file *)
    | Other  (** for testing or uncategorized sources *)
    [@@deriving compare]

  let matches ~caller ~callee = Int.equal 0 (compare caller callee)

  let of_string = function
    | "CommandLineFlag" ->
        L.die UserError "User-specified CommandLineFlag sources are not supported"
    | "Endpoint" ->
        Endpoint (Mangled.from_string "NONE", Typ.Tvoid)
    | "EnvironmentVariable" ->
        EnvironmentVariable
    | "File" ->
        File
    | _ ->
        Other


  let external_sources =
    List.map
      ~f:(fun {QuandaryConfig.Source.procedure; kind; index} ->
        (QualifiedCppName.Match.of_fuzzy_qual_names [procedure], kind, index))
      (QuandaryConfig.Source.of_json Config.quandary_sources)


  let endpoints = String.Set.of_list (QuandaryConfig.Endpoint.of_json Config.quandary_endpoints)

  (* return Some(source kind) if [procedure_name] is in the list of externally specified sources *)
  let get_external_source qualified_pname =
    let return = None in
    List.find_map
      ~f:(fun (qualifiers, kind, index) ->
        if QualifiedCppName.Match.match_qualifiers qualifiers qualified_pname then
          let source_index =
            try Some (int_of_string index)
            with Failure _ -> return
          in
          Some (of_string kind, source_index)
        else None)
      external_sources


  let get pname actuals _ =
    let return = None in
    match pname with
    | Typ.Procname.ObjC_Cpp cpp_name
      -> (
        let qualified_pname = Typ.Procname.get_qualifiers pname in
        match
          ( QualifiedCppName.to_list
              (Typ.Name.unqualified_name (Typ.Procname.objc_cpp_get_class_type_name cpp_name))
          , Typ.Procname.get_method pname )
        with
        | ( ["std"; ("basic_istream" | "basic_iostream")]
          , ("getline" | "read" | "readsome" | "operator>>") ) ->
            Some (File, Some 1)
        | _ ->
            get_external_source qualified_pname )
    | Typ.Procname.C _ when Typ.Procname.equal pname BuiltinDecl.__global_access
      -> (
        (* is this var a command line flag created by the popular C++ gflags library for creating
           command-line flags (https://github.com/gflags/gflags)? *)
        let is_gflag access_path =
          let pvar_is_gflag pvar =
            String.is_substring ~substring:"FLAGS_" (Pvar.get_simplified_name pvar)
          in
          match access_path with
          | (Var.ProgramVar pvar, _), _ ->
              Pvar.is_global pvar && pvar_is_gflag pvar
          | _ ->
              false
        in
        (* accessed global will be passed to us as the only parameter *)
        match actuals with
        | [(HilExp.AccessPath access_path)] when is_gflag access_path ->
            let (global_pvar, _), _ = access_path in
            Some (CommandLineFlag global_pvar, None)
        | _ ->
            None )
    | Typ.Procname.C _ -> (
      match Typ.Procname.to_string pname with
      | "getenv" ->
          Some (EnvironmentVariable, return)
      | _ ->
          get_external_source (Typ.Procname.get_qualifiers pname) )
    | Typ.Procname.Block _ ->
        None
    | pname ->
        L.(die InternalError) "Non-C++ procname %a in C++ analysis" Typ.Procname.pp pname


  let get_tainted_formals pdesc _ =
    let get_tainted_formals_ qualified_pname =
      if String.Set.mem endpoints qualified_pname then
        List.map
          ~f:(fun (name, typ) -> (name, typ, Some (Endpoint (name, typ.Typ.desc))))
          (Procdesc.get_formals pdesc)
      else Source.all_formals_untainted pdesc
    in
    match Procdesc.get_proc_name pdesc with
    | Typ.Procname.ObjC_Cpp objc as pname ->
        let qualified_pname =
          F.sprintf "%s::%s"
            (Typ.Procname.objc_cpp_get_class_name objc)
            (Typ.Procname.get_method pname)
        in
        get_tainted_formals_ qualified_pname
    | Typ.Procname.C _ as pname ->
        get_tainted_formals_ (Typ.Procname.get_method pname)
    | _ ->
        Source.all_formals_untainted pdesc


  let pp fmt = function
    | Endpoint (formal_name, _) ->
        F.fprintf fmt "Endpoint[%s]" (Mangled.to_string formal_name)
    | EnvironmentVariable ->
        F.fprintf fmt "EnvironmentVariable"
    | File ->
        F.fprintf fmt "File"
    | CommandLineFlag var ->
        F.fprintf fmt "CommandLineFlag[%a]" Var.pp var
    | Other ->
        F.fprintf fmt "Other"

end

module CppSource = Source.Make (SourceKind)

module SinkKind = struct
  type t =
    | BufferAccess  (** read/write an array *)
    | HeapAllocation  (** heap memory allocation *)
    | ShellExec  (** shell exec function *)
    | SQL  (** SQL query *)
    | StackAllocation  (** stack memory allocation *)
    | Other  (** for testing or uncategorized sinks *)
    [@@deriving compare]

  let matches ~caller ~callee = Int.equal 0 (compare caller callee)

  let of_string = function
    | "BufferAccess" ->
        BufferAccess
    | "HeapAllocation" ->
        HeapAllocation
    | "ShellExec" ->
        ShellExec
    | "SQL" ->
        SQL
    | "StackAllocation" ->
        StackAllocation
    | _ ->
        Other


  let external_sinks =
    List.map
      ~f:(fun {QuandaryConfig.Sink.procedure; kind; index} ->
        (QualifiedCppName.Match.of_fuzzy_qual_names [procedure], kind, index))
      (QuandaryConfig.Sink.of_json Config.quandary_sinks)


  (* taint the nth parameter (0-indexed) *)
  let taint_nth n kind actuals =
    if n < List.length actuals then Some (kind, IntSet.singleton n) else None


  let taint_all kind actuals =
    Some (kind, IntSet.of_list (List.mapi ~f:(fun actual_num _ -> actual_num) actuals))


  (* return Some(sink kind) if [procedure_name] is in the list of externally specified sinks *)
  let get_external_sink pname actuals =
    let qualified_pname = Typ.Procname.get_qualifiers pname in
    List.find_map
      ~f:(fun (qualifiers, kind, index) ->
        if QualifiedCppName.Match.match_qualifiers qualifiers qualified_pname then
          let kind = of_string kind in
          try
            let n = int_of_string index in
            taint_nth n kind actuals
          with Failure _ ->
            (* couldn't parse the index, just taint everything *)
            taint_all kind actuals
        else None)
      external_sinks


  let get pname actuals _ =
    let is_buffer_like pname =
      (* assume it's a buffer class if it's "vector-y", "array-y", or "string-y". don't want to
         report on accesses to maps etc., but also want to recognize custom vectors like fbvector
         rather than overfitting to std::vector *)
      let typename =
        Typ.Procname.get_qualifiers pname |> QualifiedCppName.strip_template_args
        |> QualifiedCppName.to_qual_string |> String.lowercase
      in
      String.is_substring ~substring:"vec" typename
      || String.is_substring ~substring:"array" typename
      || String.is_substring ~substring:"string" typename
    in
    match pname with
    | Typ.Procname.ObjC_Cpp _ -> (
      match Typ.Procname.get_method pname with
      | "operator[]" when Config.developer_mode && is_buffer_like pname ->
          taint_nth 1 BufferAccess actuals
      | _ ->
          get_external_sink pname actuals )
    | Typ.Procname.C _
      when Config.developer_mode && Typ.Procname.equal pname BuiltinDecl.__array_access ->
        taint_all BufferAccess actuals
    | Typ.Procname.C _ when Typ.Procname.equal pname BuiltinDecl.__set_array_length ->
        (* called when creating a stack-allocated array *)
        taint_nth 1 StackAllocation actuals
    | Typ.Procname.C _ -> (
      match Typ.Procname.to_string pname with
      | "execl" | "execlp" | "execle" | "execv" | "execve" | "execvp" | "system" ->
          taint_all ShellExec actuals
      | "popen" ->
          taint_nth 0 ShellExec actuals
      | ("brk" | "calloc" | "malloc" | "realloc" | "sbrk") when Config.developer_mode ->
          taint_all HeapAllocation actuals
      | "strcpy" when Config.developer_mode ->
          (* warn if source array is tainted *)
          taint_nth 1 BufferAccess actuals
      | "memcpy"
      | "memmove"
      | "memset"
      | "strncpy"
      | "wmemcpy"
      | "wmemmove"
        when Config.developer_mode ->
          (* warn if count argument is tainted *)
          taint_nth 2 BufferAccess actuals
      | _ ->
          get_external_sink pname actuals )
    | Typ.Procname.Block _ ->
        None
    | pname ->
        L.(die InternalError) "Non-C++ procname %a in C++ analysis" Typ.Procname.pp pname


  let pp fmt kind =
    F.fprintf fmt
      ( match kind with
      | BufferAccess ->
          "BufferAccess"
      | HeapAllocation ->
          "HeapAllocation"
      | ShellExec ->
          "ShellExec"
      | SQL ->
          "SQL"
      | StackAllocation ->
          "StackAllocation"
      | Other ->
          "Other" )

end

module CppSink = Sink.Make (SinkKind)

include Trace.Make (struct
  module Source = CppSource
  module Sink = CppSink

  let get_report source sink =
    (* using this to match custom string wrappers such as folly::StringPiece *)
    let is_stringy typ =
      let lowercase_typ = String.lowercase (Typ.to_string (Typ.mk typ)) in
      String.is_substring ~substring:"string" lowercase_typ
      || String.is_substring ~substring:"char*" lowercase_typ
    in
    match (Source.kind source, Sink.kind sink) with
    | Endpoint _, BufferAccess ->
        (* untrusted data from an endpoint flowing into a buffer *)
        Some IssueType.quandary_taint_error
    | Endpoint (_, typ), ShellExec ->
        (* untrusted string data flowing to shell ShellExec *)
        Option.some_if (is_stringy typ) IssueType.shell_injection
    | Endpoint (_, typ), SQL ->
        (* untrusted string data flowing to SQL *)
        Option.some_if (is_stringy typ) IssueType.sql_injection
    | (CommandLineFlag _ | EnvironmentVariable | File | Other), BufferAccess ->
        (* untrusted flag, environment var, or file data flowing to buffer *)
        Some IssueType.quandary_taint_error
    | (CommandLineFlag _ | EnvironmentVariable | File | Other), ShellExec ->
        (* untrusted flag, environment var, or file data flowing to shell *)
        Some IssueType.shell_injection
    | (CommandLineFlag _ | EnvironmentVariable | File | Other), SQL ->
        (* untrusted flag, environment var, or file data flowing to SQL *)
        Some IssueType.sql_injection
    | (CommandLineFlag _ | Endpoint _ | EnvironmentVariable | File | Other), HeapAllocation ->
        (* untrusted data of any kind flowing to heap allocation. this can cause crashes or DOS. *)
        Some IssueType.quandary_taint_error
    | (CommandLineFlag _ | Endpoint _ | EnvironmentVariable | File | Other), StackAllocation ->
        (* untrusted data of any kind flowing to stack buffer allocation. trying to allocate a stack
           buffer that's too large will cause a stack overflow. *)
        Some IssueType.untrusted_variable_length_array
    | Other, _ ->
        (* Other matches everything *)
        Some IssueType.quandary_taint_error
    | _, Other ->
        Some IssueType.quandary_taint_error

end)
