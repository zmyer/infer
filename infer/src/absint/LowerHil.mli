(*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd

module type HilConfig = sig
  val include_array_indexes : bool
  (** if true, array index expressions will appear in access paths *)
end

module DefaultConfig : HilConfig

(** Functor for turning HIL transfer functions into SIL transfer functions *)
module Make
    (MakeTransferFunctions : TransferFunctions.MakeHIL)
    (HilConfig : HilConfig)
    (CFG : ProcCfg.S) : sig
  module TransferFunctions : module type of MakeTransferFunctions (CFG)

  module CFG : module type of TransferFunctions.CFG

  module Domain :
      module type of AbstractDomain.Pair (TransferFunctions.Domain) (IdAccessPathMapDomain)

  type extras = TransferFunctions.extras

  val exec_instr : Domain.astate -> extras ProcData.t -> CFG.node -> Sil.instr -> Domain.astate
end

(** Wrapper around Interpreter to prevent clients from having to deal with IdAccessPathMapDomain *)
module MakeAbstractInterpreter
    (CFG : ProcCfg.S)
    (MakeTransferFunctions : TransferFunctions.MakeHIL) : sig
  module Interpreter :
      module type of AbstractInterpreter.Make (CFG) (Make (MakeTransferFunctions) (DefaultConfig))

  val compute_post :
    Interpreter.TransferFunctions.extras ProcData.t
    -> initial:MakeTransferFunctions(CFG).Domain.astate
    -> MakeTransferFunctions(CFG).Domain.astate option
  (** compute and return the postcondition for the given procedure starting from [initial]. If
      [debug] is true, print html debugging output. *)
end
