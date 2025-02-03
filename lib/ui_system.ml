open! Containers
open Lwt.Syntax
module IdMap = Map.Make (Id)

type ack = Ack of Ptime.span | Nothing

type msg = {contents : string; ack : ack}

type state = {msgs : msg IdMap.t; id_queue : Id.t Queue.t}

let empty_state = {msgs = IdMap.empty; id_queue = Queue.create ()}

let state_mbox = Lwt_mvar.create empty_state

module Print = struct
  let msg msg =
    let ack =
      match msg.ack with
      | Nothing -> ""
      | Ack span -> Format.asprintf "[%a]" Ptime.Span.pp span
    in
    Format.asprintf "%s %s@." msg.contents ack

  let escape buf seq =
    Buffer.add_char buf '\x1b' ;
    Buffer.add_string buf seq

  let go_blue buf = escape buf "[1;34m"

  let go_green buf = escape buf "[1;32m"

  let go_white buf = escape buf "[1;37m"

  let state state =
    let buf = Buffer.create 1000 in
    escape buf "[2J" ;
    let fold _ msg_ =
      (match msg_.ack with Nothing -> go_green buf | Ack _ -> go_blue buf) ;
      Buffer.add_string buf @@ msg msg_
    in
    IdMap.iter fold state.msgs ;
    go_white buf;
    Buffer.add_string buf "> " ;
    Lwt_fmt.printf "%s@?" @@ Buffer.contents buf
end

let add_msg id contents =
  let* state = Lwt_mvar.take state_mbox in
  Queue.add id state.id_queue ;
  (* Remove some messages if there's too many *)
  let msgs =
    match Queue.length state.id_queue > Config.max_msgs_ram with
    | false -> state.msgs
    | true ->
        let id = Queue.pop state.id_queue in
        IdMap.remove id state.msgs
  in
  let msg = {contents; ack = Nothing} in
  let msgs = IdMap.add id msg msgs in
  let state = {state with msgs} in
  let* () = Print.state state in
  Lwt_mvar.put state_mbox state

let add_ack id ack_span =
  let* state = Lwt_mvar.take state_mbox in
  let update = function
    | None -> None
    | Some msg -> Some {msg with ack = Ack ack_span}
  in
  let msgs = IdMap.update id update state.msgs in
  let state = {state with msgs} in
  let* () = Print.state state in
  Lwt_mvar.put state_mbox state

let print_default () = Print.state empty_state
