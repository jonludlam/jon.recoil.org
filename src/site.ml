open Cowabloga
open Lwt

let nav_links = [
    "About", Uri.of_string "/about";
    "Blog", Uri.of_string "/blog";
    "Code", Uri.of_string "/code";
  ]

let top_nav =
  Foundation.top_nav
    ~title:<:html< jon.recoil.org >>
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
  let copyright = <:html<Jon Ludlam>> in
  let { Atom_feed.title; subtitle } = config in
  Lwt.return (Foundation.Blog.t ~title ~subtitle ~sidebar ~posts ~copyright ())

let blog read_entry =
  let headers = <:html< 
    <link rel="stylesheet" href="css/foundation-icons.css" /> 
  >> in
  t read_entry >>= fun t -> 
  let content = top_nav @ t in
  let body = Foundation.body ~highlight:"/css/magula.css" ~title:"jon.recoil.org | blog" ~headers ~content ~trailers:[] () in
  Lwt.return (Foundation.page ~body)

let about =
  let headers = <:html<
    <link rel="stylesheet" href="css/foundation-icons.css" />
    <link rel="stylesheet" href="css/app.css" />
  >> in
  let content = top_nav @ <:html<
      <section class="hero">
	<div class="row">
          <div class="medium-4 medium-offset-4">
            <p>Nothing to see here</p>
          </div>
        </div>
      </section>
  >> in
  let body = Foundation.body ~title:"jon.recoil.org | about" ~headers ~content ~trailers:[] () in
  Foundation.page ~body

let code =
  let headers = <:html<
    <link rel="stylesheet" href="css/foundation-icons.css" />
    <link rel="stylesheet" href="css/app.css" />
  >> in
  let content = top_nav @ <:html<
      <section class="hero">
	<div class="row">
          <div class="medium-4 medium-offset-4">
            <p>Nothing to see here</p>
          </div>
        </div>
      </section>
  >> in
  let body = Foundation.body ~title:"jon.recoil.org | code" ~headers ~content ~trailers:[] () in
  Foundation.page ~body
  
let index = 
  let headers = <:html<
    <link rel="stylesheet" href="css/foundation-icons.css" />
    <link rel="stylesheet" href="css/app.css" />
  >> in
  let content = top_nav @ <:html<
      <section class="hero">
	<div class="row">
	  <div class="medium-5 medium-text-justify columns">
	    <img src="img/me.jpg" alt="me"></img>
	  </div>
	  <div class="medium-7 medium-left-text columns">
            <h2>Hi, I'm Jon Ludlam</h2>
            <p>I'm a fellow of <a href="http://www.chu.cam.ac.uk/">Churchill College</a> in Cambridge and I work on <a href="http://github.com/xapi-project">open source software</a> at <a href="http://www.citrix.com/">Citrix</a>.</p>
	    <p><a href="http://www.github.com/jonludlam"><i class="fi-social-github"> </i>&nbsp;http://www.github.com/jonludlam</a></p>
	    <p><a href="http://www.twitter.com/jonludlam"><i class="fi-social-twitter"> </i>&nbsp;http://www.twitter.com/jonludlam</a></p>
	    <p><a href="https://uk.linkedin.com/in/jonludlam"><i class="fi-social-linkedin"> </i>&nbsp;https://uk.linkedin.com/in/jonludlam</a></p>
	    <p><a href="https://google.com/+JonLudlam"><i class="fi-social-google-plus"> </i>&nbsp;http://google.com/+JonLudlam</a></p>
            <p><a href="https://flickr.com/photos/jonludlam"><i class="fi-social-flickr"> </i>&nbsp;http://flickr.com/photos/jonludlam</a></p>
	  </div>
	</div>
	<div class="row">
	  <div class="medium-7 medium-offset-3"><hr/></div>
	  <div class="medium-2"></div>
	</div>
      </section>
  >> in
  let body = Foundation.body ~title:"jon.recoil.org" ~headers ~content ~trailers:[] () in
  Foundation.page ~body
