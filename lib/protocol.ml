open! Containers
open! Utils

type msg_type = Ack | Send [@@deriving yojson]

type msg = Ack of Id.t | Msg of {id : int; contents : string}
[@@deriving yojson]

type encoded = string

let from_encoded_string t = t

let to_encoded_string t = t

let max_encoding_len =
  let msg = Msg {id = max_int; contents = ""} in
  let str = Yojson.Safe.to_string @@ msg_to_yojson msg in
  String.length str

module Encode = struct
  let ack id =
    let msg = Ack id in
    let json = msg_to_yojson msg in
    Yojson.Safe.to_string json

  let split_msg msg =
    let max_chunk_size = Config.max_msg_size in
    let contents_list = String.split_len msg max_chunk_size in
    contents_list

  let encode_small id contents =
    let msg = Msg {contents; id} in
    let json = msg_to_yojson msg in
    Yojson.Safe.to_string json

  let split_encode id contents =
    let contents_list = split_msg contents in
    List.map (encode_small id) contents_list
end

module Decode = struct
  let decode_msg msg =
    match Yojson.Safe.from_string msg with
    | msg_json -> msg_of_yojson msg_json
    | exception _ -> Error "end of json input"
end
