open Cow
open Cowabloga
open Date
open Blog

let me = {
  Atom.name = "Jon Ludlam";
  uri = Some "http://jon.recoil.org";
  email = Some "jon@recoil.org";
}

let entries = Entry.([
    { updated = date (2014, 06, 12, 12, 0);
      authors = [me];
      subject = "Tracking down stress test bugs in xapi";
      body = "tracking-down-stress-test-bugs-in-xapi.md";
      permalink = "tracking-down-stress-test-bugs-in-xapi";
    }
])
