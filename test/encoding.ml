open Ahrefs_chat

let test =
  let open Protocol in
  QCheck.Test.make
    ~count:1000
    ~name:"encoding-decoding"
    QCheck.(string)
    (fun s ->
      let enc = Encode.split_encode 0 s in
      let dec = List.map Decode.decode_msg enc in
      let str = List.map Result.get_ok dec in
      let str =
        List.filter_map
          (function Ack _ -> None | Msg c -> Some c.contents)
          str
      in
      let str = String.concat "" str in
      str = s)

let _ = QCheck_runner.run_tests_main [test]
