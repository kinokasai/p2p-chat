open Containers
open Ahrefs_chat.Utils

let print_list l =
  let pp_start fpf () = Format.fprintf fpf "[" in
  let pp_stop fpf () = Format.fprintf fpf "]" in
  Format.printf "%a@." (List.pp ~pp_start ~pp_stop String.pp) l

let%expect_test "empty string split" =
  let l = String.split_len "" 3 in
  print_list l ;
  [%expect {| [] |}]

let%expect_test "bigstring small split" =
  let s = String.init 30 (fun _ -> 'a') in
  let l = String.split_len s 5 in
  print_list l ;
  [%expect
    {|
    ["aaaaa", "aaaaa", "aaaaa", "aaaaa", "aaaaa",
    "aaaaa"]
    |}]

let%expect_test "smallstring split" =
  let l = String.split_len "abc" 100 in
  print_list l ;
  [%expect {| ["abc"] |}]

let%expect_test "split 0" =
  try
    let l = String.split_len "a" 0 in
    print_list l
  with Invalid_argument s ->
    Format.printf "invalid arg: %s@." s ;
    [%expect {| invalid arg: split_len: 0 |}]
