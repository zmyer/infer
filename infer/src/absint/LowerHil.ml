(*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd
module L = Logging

module type HilConfig = sig
  val include_array_indexes : bool
end

module DefaultConfig : HilConfig = struct
  let include_array_indexes = false
end

module Make
    (MakeTransferFunctions : TransferFunctions.MakeHIL)
    (HilConfig : HilConfig)
    (CFG : ProcCfg.S) =
struct
  module TransferFunctions = MakeTransferFunctions (CFG)
  module CFG = TransferFunctions.CFG
  module Domain = AbstractDomain.Pair (TransferFunctions.Domain) (IdAccessPathMapDomain)

  type extras = TransferFunctions.extras

  let pp_pre_post pre post hil_instr node =
    if Config.write_html then
      let underyling_node = CFG.underlying_node node in
      NodePrinter.start_session underyling_node ;
      L.d_strln
        (Format.asprintf "PRE: %a@.INSTR: %a@.POST: %a@." TransferFunctions.Domain.pp pre
           HilInstr.pp hil_instr TransferFunctions.Domain.pp post) ;
      NodePrinter.finish_session underyling_node


  let exec_instr ((actual_state, id_map) as astate) extras node instr =
    let f_resolve_id id =
      try Some (IdAccessPathMapDomain.find id id_map)
      with Not_found -> None
    in
    match
      HilInstr.of_sil ~include_array_indexes:HilConfig.include_array_indexes ~f_resolve_id instr
    with
    | Bind (id, access_path) ->
        let id_map' = IdAccessPathMapDomain.add id access_path id_map in
        if phys_equal id_map id_map' then astate else (actual_state, id_map')
    | Unbind ids ->
        let id_map' =
          List.fold ~f:(fun acc id -> IdAccessPathMapDomain.remove id acc) ~init:id_map ids
        in
        if phys_equal id_map id_map' then astate else (actual_state, id_map')
    | Instr (Call (_, Direct callee_pname, _, _, loc) as hil_instr)
      when Typ.Procname.equal callee_pname BuiltinDecl.__delete_locked_attribute ->
        (* need to be careful not to move reads/writes out of a critical section. to ensure this,
           "dump" all of the temporaries out of the id map, then execute the unlock instruction. *)
        let actual_state' =
          IdAccessPathMapDomain.fold
            (fun id access_path astate_acc ->
              let lhs_access_path = ((id, Typ.mk Typ.Tvoid), []) in
              let dummy_assign =
                HilInstr.Assign (lhs_access_path, HilExp.AccessPath access_path, loc)
              in
              TransferFunctions.exec_instr astate_acc extras node dummy_assign)
            id_map actual_state
        in
        let actual_state'' = TransferFunctions.exec_instr actual_state' extras node hil_instr in
        pp_pre_post actual_state actual_state'' hil_instr node ;
        (actual_state'', IdAccessPathMapDomain.empty)
    | Instr hil_instr ->
        let actual_state' = TransferFunctions.exec_instr actual_state extras node hil_instr in
        pp_pre_post actual_state actual_state' hil_instr node ;
        if phys_equal actual_state actual_state' then astate else (actual_state', id_map)
    | Ignore ->
        astate

end

module MakeAbstractInterpreter
    (CFG : ProcCfg.S)
    (MakeTransferFunctions : TransferFunctions.MakeHIL) =
struct
  module Interpreter =
    AbstractInterpreter.Make (CFG) (Make (MakeTransferFunctions) (DefaultConfig))

  let compute_post proc_data ~initial =
    let initial' = (initial, IdAccessPathMapDomain.empty) in
    Option.map ~f:fst (Interpreter.compute_post ~debug:false proc_data ~initial:initial')
end
