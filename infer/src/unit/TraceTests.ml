(*
 * Copyright (c) 2016 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd
module L = Logging
module F = Format

module MockTraceElem = struct
  type t = Kind1 | Kind2 | Footprint [@@deriving compare]

  let matches ~caller ~callee = Int.equal 0 (compare caller callee)

  let call_site _ = CallSite.dummy

  let kind t = t

  let make ?indexes:_ kind _ = kind

  let pp fmt = function
    | Kind1 ->
        F.fprintf fmt "Kind1"
    | Kind2 ->
        F.fprintf fmt "Kind2"
    | Footprint ->
        F.fprintf fmt "Footprint"


  module Kind = struct
    type nonrec t = t

    let compare = compare

    let matches = matches

    let pp = pp
  end

  module Set = PrettyPrintable.MakePPSet (struct
    type nonrec t = t

    let compare = compare

    let pp = pp
  end)

  let with_callsite t _ = t
end

module MockSource = struct
  include Source.Make (struct
    include MockTraceElem

    let get _ _ = assert false

    let get_tainted_formals _ = assert false
  end)

  let equal = [%compare.equal : t]
end

module MockSink = struct
  include MockTraceElem

  type parameter = {sink: t; index: int}

  let get _ = assert false

  let indexes _ = IntSet.empty

  let equal = [%compare.equal : t]
end

module MockTrace = Trace.Make (struct
  module Source = MockSource
  module Sink = MockSink

  let get_report source sink =
    if [%compare.equal : MockTraceElem.t] (Source.kind source) (Sink.kind sink) then
      Some IssueType.quandary_taint_error
    else None

end)

let trace_equal t1 t2 = MockTrace.( <= ) ~lhs:t1 ~rhs:t2 && MockTrace.( <= ) ~lhs:t2 ~rhs:t1

let source_equal path_source source =
  match path_source with
  | MockTrace.Known s ->
      MockSource.equal s source
  | MockTrace.Footprint _ ->
      false


let tests =
  let source1 = MockSource.make MockTraceElem.Kind1 CallSite.dummy in
  let source2 = MockSource.make MockTraceElem.Kind2 CallSite.dummy in
  let sink1 = MockSink.make MockTraceElem.Kind1 CallSite.dummy in
  let sink2 = MockSink.make MockTraceElem.Kind2 CallSite.dummy in
  let open OUnit2 in
  let get_reports =
    let get_reports_ _ =
      let trace =
        MockTrace.of_source source1 |> MockTrace.add_source source2 |> MockTrace.add_sink sink1
        |> MockTrace.add_sink sink2
      in
      let reports = MockTrace.get_reports trace in
      assert_equal (List.length reports) 2 ;
      assert_bool "Reports should contain source1 -> sink1"
        (List.exists
           ~f:(fun {MockTrace.path_source; path_sink} ->
             source_equal path_source source1 && MockSink.equal path_sink sink1)
           reports) ;
      assert_bool "Reports should contain source2 -> sink2"
        (List.exists
           ~f:(fun {MockTrace.path_source; path_sink} ->
             source_equal path_source source2 && MockSink.equal path_sink sink2)
           reports)
    in
    "get_reports" >:: get_reports_
  in
  let append =
    let append_ _ =
      let call_site = CallSite.dummy in
      let footprint_ap =
        AccessPath.Abs.Exact (AccessPath.of_id (Ident.create_none ()) (Typ.mk Tvoid))
      in
      let source_trace = MockTrace.of_source source1 in
      let footprint_trace = MockTrace.of_footprint footprint_ap |> MockTrace.add_sink sink1 in
      let expected_trace = MockTrace.of_source source1 |> MockTrace.add_sink sink1 in
      assert_bool "Appended trace should contain source and sink"
        (trace_equal (MockTrace.append source_trace footprint_trace call_site) expected_trace)
    in
    "append" >:: append_
  in
  "trace_domain_suite" >::: [get_reports; append]

