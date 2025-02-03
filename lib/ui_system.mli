(** Adds a message to the UI *)
val add_msg : Id.t -> string -> unit Lwt.t
(** Adds an ack to the UI *)
val add_ack : Id.t -> Ptime.span -> unit Lwt.t

(** Prints the default UI state *)
val print_default : unit -> unit Lwt.t
