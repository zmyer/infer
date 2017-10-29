(*
 * Copyright (c) 2017 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)
open! IStd
module F = Format

type error = ExternalError | InternalError | UserError

exception InferExternalError of string

exception InferInternalError of string

exception InferUserError of string

exception InferExit of int

let raise_error error ~msg =
  match error with
  | ExternalError ->
      raise (InferExternalError msg)
  | InternalError ->
      raise (InferInternalError msg)
  | UserError ->
      raise (InferUserError msg)


let die error fmt = F.kasprintf (fun msg -> raise_error error ~msg) fmt

let exit exitcode = raise (InferExit exitcode)

let exit_code_of_exception = function
  | InferUserError _ ->
      1
  | InferExternalError _ ->
      3
  | InferInternalError _ ->
      4
  | InferExit exitcode ->
      exitcode
  | _ ->
      (* exit code 2 is used by the OCaml runtime in cases of uncaught exceptions *) 2

