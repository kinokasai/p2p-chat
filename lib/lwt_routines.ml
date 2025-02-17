open Lwt
open Lwt.Syntax
open Containers

type result = ClosedSocket | ClosedStdin

let acks_mbox = Lwt_mvar.create @@ Queue.create ()

let write_encoded_msg output msg =
  Lwt_io.write_line output @@ Protocol.to_encoded_string msg

module StdinReader = struct
  let send_msg output msg =
    let split_msgs = Protocol.Encode.split_msg msg in
    let register_and_send contents =
      (* Send message to the socket writer *)
      let msg = Protocol.Encode.encode_small contents in
      let* () = write_encoded_msg output msg in
      (* Register sent timestamp *)
      let sent_span = Ptime.to_span @@ Ptime_clock.now () in
      let* acks = Lwt_mvar.take acks_mbox in
      Queue.add sent_span acks;
      Lwt_mvar.put acks_mbox acks
    in
    Lwt_list.iter_s register_and_send split_msgs

  let rec run input output =
    let* msg = Lwt_io.read_line_opt input in
    match msg with
    | None -> Lwt.return ClosedStdin
    | Some msg ->
        let* () = send_msg output msg in
        run input output
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

  let handle_msg output = function
    | Protocol.Ack ->
        let recv_ptime = Ptime.to_span @@ Ptime_clock.now () in
        let* acks = Lwt_mvar.take acks_mbox in
        let sent_ptime = Queue.take acks in
        let* () = Lwt_mvar.put acks_mbox acks in
        let diff = Ptime.Span.sub recv_ptime sent_ptime in
        Lwt_fmt.printf "roundtrip time: %a@." Ptime.Span.pp diff; 
    | Msg {contents} ->
        (* Send ack *)
        let ack = Protocol.Encode.ack () in
        let* () = write_encoded_msg output ack in
        Lwt_fmt.printf "%s@." contents

  let rec run input output =
    let max_size = Config.max_msg_size + Protocol.max_encoding_len + 1 in
    let buf = Buffer.create max_size in
    let* read_result = read_chars max_size buf input 0 in
    match read_result with
    | `Stream_end ->
        let* () = Lwt_fmt.eprintf "Other quit.@." in
        Lwt.return ClosedSocket
    | `Message_too_big ->
        let* () = Lwt_fmt.eprintf "Received message bigger than max_size@." in
        run input output
    | `Read ->
        let msg = Buffer.contents buf in
        let* () =
          match decode_msg msg with
          | Error e -> Lwt_fmt.eprintf "Could not decode message: %s@." e
          | Ok msg -> handle_msg output msg
        in
        run input output
end
