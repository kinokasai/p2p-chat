open Ahrefs_chat.Protocol

let%expect_test "hey" =
  let input = "hey" in
  let enc = Encode.split_encode 0 input in
  let dec = List.map Decode.decode_msg enc in
  let str = List.map Result.get_ok dec in
  let str =
    List.filter_map (function Ack _ -> None | Msg c -> Some c.contents) str
  in
  let str = String.concat "" str in
  Format.printf "%s = %s (%b)@." str input (input = str) ;
  [%expect {| hey = hey (true) |}]
