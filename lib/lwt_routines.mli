(** This module hosts the different Lwt routines. *)

type result = ClosedSocket | ClosedStdin

(** This routine makes sure the ui is updated.

    It consumes the mailboxes ui_message_mbox and ack_mbox *)
module UiUpdater : sig
  val run : unit -> result Lwt.t
end

(** This routine writes what's in the sock_msg mailbox to the
    socket. 

    Consumes sock_msg_mbox. *)
module SocketWriter : sig
  val run : Lwt_io.output_channel -> result Lwt.t
end

(** This routine reads stdin and puts the results to be consumed
    by UiUpdater and SocketWriter. 

    Produces sock_msg_mbox and ui_message_mbox. *)
module StdinReader : sig
  val run : Lwt_io.input_channel -> result Lwt.t
end

(** This routine reads incoming message from the socket.

    Produces ack_mbox, sock_msg_mbox, and ui_msg_mbox *)
module SocketReader : sig
  val run : Lwt_io.input_channel -> result Lwt.t
end
