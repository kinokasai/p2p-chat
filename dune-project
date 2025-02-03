(lang dune 3.0)

(name ahrefs_chat)

(generate_opam_files true)

(package
 (name ahrefs_chat)
 (depends
  (qcheck
   (and
    (>= 0.23)
    :with-test))
  (ptime
   (>= 1.2.0))
  (ppx_expect
   (>= v0.17.2))
  (ppx_deriving_yojson
   (>= 3.9.1))
  (ppx_deriving
   (>= 6.0.3))
  (lwt_ppx
   (>= 5.8.0))
  (lwt
   (>= 5.9.0))
  (containers
   (>= 3.15))
  ocaml))