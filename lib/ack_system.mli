(** Register at which point a message was sent through its id. *)
val register_ack : Id.t -> Ptime.span -> unit Lwt.t

(** Calculate the difference between the passed span and the
    one stored at the passed id. Returns it and removes it from
    the map. *)
val take_diff :
  Id.t -> Ptime.span -> Ptime.span Option.t Lwt.t
