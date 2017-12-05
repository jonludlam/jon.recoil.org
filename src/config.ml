open Mirage

(* If the Unix `MODE` is set, the choice of configuration changes:
   MODE=crunch (or nothing): use static filesystem via crunch
   MODE=fat: use FAT and block device (run ./make-fat-images.sh)
 *)
let fs = generic_kv_ro "../static"
let blog_fs = generic_kv_ro "../blog"

let stack = generic_stackv4 default_network

let server =
  http_server (conduit_direct stack)

let main =
  foreign "Dispatch.Main" (http @-> kv_ro @-> kv_ro @-> job)

let packages = [ package "cow"; package "cowabloga"; package "re" ]
let () =
  register "www" ~packages [
    main $ server $ fs $ blog_fs 
  ]
