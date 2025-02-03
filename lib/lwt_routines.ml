open Lwt
open Lwt.Syntax
open Containers

type result = ClosedSocket | ClosedStdin

type ui_message = {id : Id.t; contents : string}

type ack = {id : Id.t; ack_span : Ptime.span}

let ui_msg_mbox : ui_message Lwt_mvar.t = Lwt_mvar.create_empty ()

let sock_msg_mbox : Protocol.encoded Lwt_mvar.t = Lwt_mvar.create_empty ()

let ack_mbox : ack Lwt_mvar.t = Lwt_mvar.create_empty ()

module UiUpdater = struct
  let rec read_message () =
    let* msg = Lwt_mvar.take ui_msg_mbox in
    let* () = Ui_system.add_msg msg.id msg.contents in
    read_message ()

  let rec read_ack () =
    let* ack = Lwt_mvar.take ack_mbox in
    let* span = Ack_system.take_diff ack.id ack.ack_span in
    let* () =
      match span with
      | None -> Lwt.return ()
      | Some span -> Ui_system.add_ack ack.id span
    in
    read_ack ()

  let rec run () =
    let read_ack = read_ack () in
    let read_message = read_message () in
    let* _ = Lwt.both read_message read_ack in
    run ()
end

module SocketWriter = struct
  let rec run output =
    let* msg = Lwt_mvar.take sock_msg_mbox in
    let str = Protocol.to_encoded_string msg in
    let* () = Lwt_io.write_line output str in
    run output
end

module StdinReader = struct
  let send_msg msg =
    let split_msgs = Protocol.Encode.split_msg msg in
    let register_and_send contents =
      (* Send message to the socket writer *)
      let* id = Id.next_id () in
      let msg = Protocol.Encode.encode_small id msg in
      let* () = Lwt_mvar.put sock_msg_mbox msg in
      (* Register sent timestamp *)
      let sent_span = Ptime.to_span @@ Ptime_clock.now () in
      let* () = Ack_system.register_ack id sent_span in
      (* Add message to ui *)
      let ui_msg = {id; contents} in
      Lwt_mvar.put ui_msg_mbox ui_msg
    in
    Lwt_list.iter_s register_and_send split_msgs

  let rec run input =
    let* msg = Lwt_io.read_line_opt input in
    match msg with
    | None -> Lwt.return ClosedStdin
    | Some msg ->
        let* () = send_msg msg in
        run input
end

module SocketReader = struct
  let decode_msg msg =
    let msg = Protocol.from_encoded_string msg in
    Protocol.Decode.decode_msg msg

  let rec read_chars max_size buf input count =
    let* char = Lwt_io.read_char_opt input in
    match (char, count) with
    | (None, _) -> Lwt.return `Stream_end
    | (Some _, count) when count = max_size -> Lwt.return `Message_too_big
    | (Some '\n', _) ->
        Buffer.add_char buf '\n' ;
        return `Read
    | (Some c, _) ->
        Buffer.add_char buf c ;
        read_chars max_size buf input (count + 1)

  let handle_msg = function
    | Protocol.Ack id ->
        let ack_span = Ptime.to_span @@ Ptime_clock.now () in
        Lwt_mvar.put ack_mbox {id; ack_span}
    | Msg {contents; id} ->
        (* Send ack *)
        let ack = Protocol.Encode.ack id in
        let* () = Lwt_mvar.put sock_msg_mbox ack in
        (* Add to ui *)
        let* id = Id.next_id () in
        let ui_msg = {id; contents} in
        Lwt_mvar.put ui_msg_mbox ui_msg

  let rec run input =
    let max_size = Config.max_msg_size + Protocol.max_encoding_len + 1 in
    let buf = Buffer.create max_size in
    let* read_result = read_chars max_size buf input 0 in
    match read_result with
    | `Stream_end ->
        let* () = Lwt_fmt.eprintf "Other quit.@." in
        Lwt.return ClosedSocket
    | `Message_too_big ->
        let* () = Lwt_fmt.eprintf "Received message bigger than max_size@." in
        run input
    | `Read ->
        let msg = Buffer.contents buf in
        let* () =
          match decode_msg msg with
          | Error e -> Lwt_fmt.eprintf "Could not decode message: %s@." e
          | Ok msg -> handle_msg msg
        in
        run input
end
