open Cowabloga
open Lwt
open Cow.Html

let nav_links = [
    "About", Uri.of_string "/about";
    "Blog", Uri.of_string "/blog";
    "Code", Uri.of_string "/code";
  ]

let top_nav =
  Foundation.top_nav
    ~title:(string "jon.recoil.org")
    ~title_uri:(Uri.of_string "/")
    ~nav_links:(Foundation.Link.top_nav ~align:`Right nav_links)

let t read_entry =
  let config = {
    Atom_feed.base_uri="http://localhost:8081";
    id = "";
    title = "Notes & Jottings";
    subtitle = None;
    rights = None;
    author = None;
    read_entry
  } in
  Blog.to_html config Entries.entries >>= fun posts ->
  let recent_posts = Blog.recent_posts config Entries.entries in
  let sidebar = Foundation.Sidebar.t ~title:"Recent Posts" ~content:recent_posts in
  let copyright = string "Jon Ludlam" in
  let { Atom_feed.title; subtitle } = config in
  Lwt.return (Foundation.Blog.t ~title ~subtitle ~sidebar ~posts ~copyright ())

let blog read_entry =
  let headers = 
    tag "link" ~attrs:["rel","stylesheet"; "href", "css/foundation-icons.css"] empty
   in
  t read_entry >>= fun t -> 
  let content = top_nav @ t in
  let body = Foundation.body ~highlight:"/css/magula.css" ~title:"jon.recoil.org | blog" ~headers ~content ~trailers:[] () in
  Lwt.return (Foundation.page ~body)

let about =
  let headers = 
    (tag "link" ~attrs:["rel","stylesheet"; "href","css/foundation-icons.css"] empty) @
    (tag "link" ~attrs:["rel","stylesheet"; "href","css/app.css"] empty)
  in
  let content = top_nav @ 
      tag "section" ~attrs:["class","hero"] (
              div ~cls:"row" (
                      div ~cls:"medium-4 medium-offset-4" (
                        p (string "Nothing to see here"))))
  in
  let body = Foundation.body ~title:"jon.recoil.org | about" ~headers ~content ~trailers:[] () in
  Foundation.page ~body

let code =
  let headers = 
    (tag "link" ~attrs:["rel","stylesheet"; "href","css/foundation-icons.css"] empty) @
    (tag "link" ~attrs:["rel","stylesheet"; "href","css/app.css"] empty)
  in
  let content = top_nav @ 
      tag "section" ~attrs:["class","hero"] (
              div ~cls:"row" (
                      div ~cls:"medium-4 medium-offset-4" (
                        p (string "Nothing to see here"))))
  in
  let body = Foundation.body ~title:"jon.recoil.org | code" ~headers ~content ~trailers:[] () in
  Foundation.page ~body
  
let index = 
  let headers = 
    (tag "link" ~attrs:["rel","stylesheet"; "href","css/foundation-icons.css"] empty) @
    (tag "link" ~attrs:["rel","stylesheet"; "href","css/app.css"] empty)
  in
  let content = top_nav @ 
      tag "section" ~cls:"hero" (
	div ~cls:"row" (list [
	  div ~cls:"medium-5 medium-text-justify columns"
            (img ~alt:"me" (Uri.of_string "img/me.jpg"));
	  
	  div ~cls:"medium-7 medium-left-text columns" (list [
                  h2 (string "Hi, I'm Jon Ludlam");
            p (list [
                    string "I'm a fellow of ";
                    a (Uri.of_string "http://www.chu.cam.ac.uk/") (string "Churchill College");
                    string " in Cambridge and I work on "; 
                    a (Uri.of_string "http://github.com/xapi-project") (string "open source software");
                    string " at ";
                    a (Uri.of_string "http://www.citrix.com/") (string "Citrix");
                    string ". "]);
          ])
        ])
      )
  in
(*	    <p><a href="https://github.com/jonludlam" rel="me"><i class="fi-social-github"> </i>&nbsp;https://github.com/jonludlam</a></p>
	    <p><a href="https://twitter.com/jonludlam" rel="me"><i class="fi-social-twitter"> </i>&nbsp;https://twitter.com/jonludlam</a></p>
	    <p><a href="https://uk.linkedin.com/in/jonludlam" rel="me"><i class="fi-social-linkedin"> </i>&nbsp;https://uk.linkedin.com/in/jonludlam</a></p>
	    <p><a href="https://google.com/+JonLudlam" rel="me"><i class="fi-social-google-plus"> </i>&nbsp;https://google.com/+JonLudlam</a></p>
            <p><a href="https://www.flickr.com/people/jonludlam/" rel="me"><i class="fi-social-flickr"> </i>&nbsp;https://www.flickr.com/people/jonludlam/</a></p>
	  </div>
	</div>
	<div class="row">
	  <div class="medium-7 medium-offset-3"><hr/></div>
	  <div class="medium-2"></div>
	</div>
      </section>
  >> in*)
  let body = Foundation.body ~title:"jon.recoil.org" ~headers ~content ~trailers:[] () in
  Foundation.page ~body
