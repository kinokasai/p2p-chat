open Lwt.Syntax
open Lwt_routines

let cleanup socket = Lwt_unix.close socket

let connect_and_serve socket addr =
  let* () = Lwt_unix.connect socket addr in
  let output = Lwt_io.of_fd ~mode:Lwt_io.output socket in
  let input = Lwt_io.of_fd ~mode:Lwt_io.input socket in
  let read_socket = SocketReader.run input output in
  let read_stdin = StdinReader.run Lwt_io.stdin output in
  (* We don't care which one finished and why, we're out of here *)
  let* (_ : result) =
    Lwt.pick [read_stdin; read_socket;]
  in
  Lwt.return 0

let lwt_run socket addr hostname port =
  try%lwt
    Lwt.finalize
      (fun () -> connect_and_serve socket addr)
      (fun () -> cleanup socket)
  with
  | Unix.Unix_error (Unix.ECONNREFUSED, _, _) ->
      let* () = Lwt_fmt.eprintf "No open socket at %s:%d.@." hostname port in
      Lwt.return 2
  | exn ->
      let* () = Lwt_fmt.eprintf "%s@." @@ Printexc.to_string exn in
      Lwt.return 3

let run hostname port =
  let open Lwt_unix in
  let host = Unix.inet_addr_of_string hostname in
  let addr = ADDR_INET (host, port) in
  let socket = socket ~cloexec:true PF_INET SOCK_STREAM 0 in
  let exit_code = Lwt_main.run @@ lwt_run socket addr hostname port in
  exit exit_code
