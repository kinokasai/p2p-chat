open Lwt.Syntax
open Lwt_routines

exception Sigint

let rec serve socket =
  try%lwt
    let* () = Lwt_fmt.eprintf "waiting for a connection...@." in
    let* (csocket, _) = Lwt_unix.accept ~cloexec:true socket in
    let* () = Ui_system.print_default () in
    let input = Lwt_io.of_fd ~mode:Lwt_io.input csocket in
    let output = Lwt_io.of_fd ~mode:Lwt_io.output csocket in
    let read_socket = SocketReader.run input in
    let read_stdin = StdinReader.run Lwt_io.stdin in
    let write_socket = SocketWriter.run output in
    let update_ui = UiUpdater.run () in
    let* result = Lwt.pick [read_socket; write_socket; read_stdin; update_ui] in
    match result with
    (* Stdin being closed means we Ctrl-D probably.*)
    | ClosedStdin -> Lwt.return_unit
    | ClosedSocket -> serve socket
  with
  | Unix.Unix_error (Unix.ECONNRESET, _, _) ->
      let* () = Lwt_fmt.eprintf "Connection reset. relaunching.@." in
      serve socket
  | e -> Lwt.reraise e

let bind_and_serve socket addr =
  let* () = Lwt_unix.bind socket addr in
  Lwt_unix.listen socket 0 ;
  let* () = serve socket in
  Lwt.return_unit

let cleanup socket = Lwt_unix.close socket

(* We ignore signal cause it's a meanie. When you can't write
  to the socket, because the client disconnected for example,
  it tries to kill us :( *)
let () = Sys.set_signal Sys.sigpipe Sys.Signal_ignore

(* The code uses the Lwt.wait workaround for handling sigint:
  https://github.com/ocsigen/lwt/issues/451#issuecomment-325554763

  The problem is that the main Lwt thread does not know when the
  exception raises because of the interrupt. To remedy this, we
  create a promise `signal` that ends when the exception is raised,
  through `wakeup_later_exn`. We wait on either `signal` or the 
  normal path before ending and cleaning.
  *)

let lwt_run socket addr =
  try%lwt
    let (signal, sig_rslvr) = Lwt.wait () in
    let on_sigint _ = Lwt.wakeup_later_exn sig_rslvr Sigint in
    Lwt_unix.on_signal Sys.sigint on_sigint |> ignore ;
    let bind_and_serve = bind_and_serve socket addr in
    let* () =
      Lwt.finalize
        (fun () -> Lwt.choose [bind_and_serve; signal])
        (fun () -> cleanup socket)
    in
    Lwt.return 0
  with
  | Unix.Unix_error (Unix.ECONNREFUSED, _, _) ->
      let* () = Lwt_fmt.eprintf "Connection to socket refused.@." in
      Lwt.return 2
  | Sigint -> Lwt.return 0
  | exn ->
      let exn_str = Printexc.to_string exn in
      let* () = Lwt_fmt.eprintf "got exn: %s@." exn_str in
      Lwt.return 2

let run port =
  let open Lwt_unix in
  let open! Lwt.Infix in
  let host = Unix.inet_addr_loopback in
  let addr = ADDR_INET (host, port) in
  let hostr = Unix.string_of_inet_addr host in
  let socket = socket ~cloexec:true PF_INET SOCK_STREAM 0 in
  Format.eprintf "launching server on %s:%d\n@." hostr port ;
  let exit_code = Lwt_main.run (lwt_run socket addr) in
  exit exit_code
