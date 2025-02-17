(** This module hosts the different Lwt routines. *)

type result = ClosedSocket | ClosedStdin


module StdinReader : sig
  val run : Lwt_io.input_channel -> Lwt_io.output_channel -> result Lwt.t
end

module SocketReader : sig
  val run : Lwt_io.input_channel -> Lwt_io.output_channel -> result Lwt.t
end
