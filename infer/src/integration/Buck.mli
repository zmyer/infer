(*
 * Copyright (c) 2016 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd

type flavored_arguments = {command: string; rev_not_targets: string list; targets: string list}

val add_flavors_to_buck_arguments :
  filter_kind:bool -> dep_depth:int option option -> extra_flavors:string list -> string list
  -> flavored_arguments
(** Add infer flavors to the targets in the given buck arguments, depending on the infer analyzer. For
    instance, in capture mode, the buck command:
    build //foo/bar:baz#some,flavor
    becomes:
    build //foo/bar:baz#infer-capture-all,some,flavor
*)

val store_args_in_file : string list -> string list
(** Given a list of arguments, stores them in a file if needed and returns the new command line *)

val filter_compatible : [> `Targets] -> string list -> string list
(** keep only the options compatible with the given Buck subcommand *)
