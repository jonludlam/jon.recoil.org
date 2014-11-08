open Lwt
open Printf
open V1_LWT

module Main (C:CONSOLE) (FS:KV_RO) (FS2:KV_RO) (S:Cohttp_lwt.Server) = struct

  let start c staticfs blogfs http =

    let read_fs fs name =
      FS.size fs name
      >>= function
      | `Error (FS.Unknown_key _) -> fail (Failure ("read " ^ name))
      | `Ok size ->
        FS.read fs name 0 (Int64.to_int size)
        >>= function
        | `Error (FS.Unknown_key _) -> fail (Failure ("read " ^ name))
        | `Ok bufs -> return (Cstruct.copyv bufs)
    in

    let read_fs2 fs name =
      FS2.size fs name
      >>= function
      | `Error (FS2.Unknown_key _) -> fail (Failure ("read " ^ name))
      | `Ok size ->
        FS2.read fs name 0 (Int64.to_int size)
        >>= function
        | `Error (FS2.Unknown_key _) -> fail (Failure ("read " ^ name))
        | `Ok bufs -> return (Cstruct.copyv bufs)
    in


    (* Split a URI into a list of path segments *)
    let split_path uri =
      let path = Uri.path uri in
      let rec aux = function
        | [] | [""] -> []
        | hd::tl -> hd :: aux tl
      in
      List.filter (fun e -> e <> "")
        (aux (Re_str.(split_delim (regexp_string "/") path)))
    in

    (* dispatch non-file URLs *)
    let rec dispatcher = function
      | [] | [""] | ["index.html"] ->
        S.respond_string ~status:`OK ~body:Site.index ()
      | ["about"] -> 
        S.respond_string ~status:`OK ~body:Site.about ()
      | ["blog"] ->
        Site.blog (fun name -> read_fs2 blogfs name >>= fun str -> Lwt.return (Cow.Markdown.of_string str)) >>= fun body -> 
        S.respond_string ~status:`OK ~body ()
      | ["code"] ->
        S.respond_string ~status:`OK ~body:Site.code ()
      | segments ->
        let path = String.concat "/" segments in
        try_lwt
          read_fs staticfs path
          >>= fun body ->
          S.respond_string ~status:`OK ~body ()
        with exn ->
          S.respond_not_found ()
    in

    (* HTTP callback *)
    let callback conn_id request body =
      let uri = S.Request.uri request in
      dispatcher (split_path uri)
    in
    let conn_closed conn_id () =
      let cid = Cohttp.Connection.to_string conn_id in
      C.log c (Printf.sprintf "conn %s closed" cid)
    in
    http { S.callback; conn_closed }

end
