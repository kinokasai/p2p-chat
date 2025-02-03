let run () =
  let config = Config.parse () in
  match config with
  | Server {port} -> Server.run port
  | Client {addr; port} -> Client.run addr port
