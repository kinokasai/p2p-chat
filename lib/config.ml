open Containers

type mode = Client of {addr : string; port : int} | Server of {port : int}

let max_msg_size = 300

let max_msgs_ram = 20

let print_usage () =
  Format.printf "./chat client <hostname> <port> @../chat server <port>@." ;
  exit 1

let parse_port t =
  match Int.of_string t with None -> print_usage () | Some i -> i

let parse () =
  match Sys.argv with
  | [|_; "server"; port|] -> Server {port = parse_port port}
  | [|_; "client"; addr; port|] -> Client {addr; port = parse_port port}
  | _ -> print_usage ()
