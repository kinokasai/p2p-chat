open! Containers
open Lwt.Syntax

type t = int
[@@deriving yojson]

let compare = Int.compare

let id_mbox = Lwt_mvar.create 0

let next_id () =
  let* id = Lwt_mvar.take id_mbox in
  let next_id = succ id in
  let* () = Lwt_mvar.put id_mbox next_id in
  Lwt.return id
  
