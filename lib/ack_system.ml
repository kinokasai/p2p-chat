open! Containers
open Lwt.Syntax
module IdMap = Map.Make (Id)

let map_mbox = Lwt_mvar.create IdMap.empty

let register_ack id span =
  let* map = Lwt_mvar.take map_mbox in
  let map = IdMap.add id span map in
  Lwt_mvar.put map_mbox map

let take_diff id ack_span =
  let* map = Lwt_mvar.take map_mbox in
  let sent = IdMap.find_opt id map in
  let map = IdMap.remove id map in
  let+ () = Lwt_mvar.put map_mbox map in
  Option.map (fun sent -> Ptime.Span.sub ack_span sent) sent
