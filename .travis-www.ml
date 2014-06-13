open Mirage

let ipaddr = 
   let address = Ipaddr.V4.of_string_exn "46.43.42.141" in
   let netmask = Ipaddr.V4.of_string_exn "255.255.255.128" in
   let gateways = [Ipaddr.V4.of_string_exn "46.43.42.129" ] in
   { address; netmask; gateways }

(* If the Unix `MODE` is set, the choice of configuration changes:
   MODE=crunch (or nothing): use static filesystem via crunch
   MODE=fat: use FAT and block device (run ./make-fat-images.sh)
 *)
let mode =
  try match String.lowercase (Unix.getenv "FS") with
    | "fat" -> `Fat
    | _     -> `Crunch
  with Not_found ->
    `Crunch

let fat_ro dir =
  kv_ro_of_fs (fat_of_files ~dir ())

let fs = match mode with
  | `Fat    -> fat_ro "../htdocs"
  | `Crunch -> crunch "../htdocs"

let net =
  try match Sys.getenv "NET" with
    | "direct" -> `Direct
    | "socket" -> `Socket
    | _        -> `Direct
  with Not_found -> `Direct

let dhcp =
  try match Sys.getenv "DHCP" with
    | "" -> false
    | _  -> true
  with Not_found -> false

let stack console =
  match net, dhcp with
  | `Direct, true  -> direct_stackv4_with_dhcp console tap0
  | `Direct, false -> direct_stackv4_with_static_ipv4 console tap0 ipaddr
  | `Socket, _     -> socket_stackv4 console [Ipaddr.V4.any]

let server =
  http_server 80 (stack default_console)

let main =
  foreign "Dispatch.Main" (console @-> kv_ro @-> http @-> job)

let () =
  add_to_ocamlfind_libraries ["re.str"];
  add_to_opam_packages ["re"];

  register "www" [
    main $ default_console $ fs $ server
  ]
