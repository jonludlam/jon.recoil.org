open Lwt
open Printf

module Main (S:Cohttp_lwt.S.Server) (FS:Mirage_types_lwt.KV_RO) (FS2:Mirage_types_lwt.KV_RO) = struct

  let start http staticfs blogfs =

    let read_fs fs name =
      FS.size fs name
      >>= function
      | Error e -> fail (Failure ("read " ^ name))
      | Ok size ->
        FS.read fs name 0L size
        >>= function
        | Error e -> fail (Failure ("read " ^ name))
        | Ok bufs -> return (Cstruct.copyv bufs)
    in

    let read_fs2 fs name =
      FS2.size fs name
      >>= function
      | Error _ -> fail (Failure ("read " ^ name))
      | Ok size ->
        FS2.read fs name 0L size
        >>= function
        | Error _ -> fail (Failure ("read " ^ name))
        | Ok bufs -> return (Cstruct.copyv bufs)
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
        Lwt.catch (fun () ->
          read_fs staticfs path
          >>= fun body ->
          S.respond_string ~status:`OK ~body ())
          (fun exn ->
            S.respond_not_found ())
    in

    (* HTTP callback *)
    let callback (_, conn_id) request body =
      let uri = Cohttp.Request.uri request in
      dispatcher (split_path uri)
    in
    let conn_closed (_, conn_id) =
      let cid = Cohttp.Connection.to_string conn_id in
      ()
    in
    http (`TCP 8080) (S.make ~callback ~conn_closed ())

end
