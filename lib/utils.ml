open Containers


module String = struct

  let split_len s (n : int) =
    match n > 0 with
    | false -> raise @@ Invalid_argument ("split_len: " ^ Int.to_string n)
    | true -> ();
    let len = String.length s in
    let l = List.init
      ((len + n - 1) / n)
      (fun i ->
        let start = i * n in
        let size = min n (len - start) in
        String.sub s start size) in
    l
  include String
end
