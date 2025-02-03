val max_encoding_len : int
type msg = Ack of Id.t | Msg of {id:int; contents: string}
type encoded
val from_encoded_string : string -> encoded
val to_encoded_string : encoded -> string
module Encode :
  sig
    val ack : Id.t -> encoded
    val split_msg : Containers.String.t -> string Containers.List.t
    val encode_small : int -> string -> encoded
    val split_encode : int -> Containers.String.t -> encoded list
  end
module Decode :
  sig
    val decode_msg : encoded -> msg Ppx_deriving_yojson_runtime.error_or
  end
