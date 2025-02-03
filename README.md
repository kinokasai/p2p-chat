Ahrefs-chat is a one-to-one chat implemented in OCaml, to be run in Unix with a terminal ui.

### How it works
The client and server both run the same code.
They run 4 lwt routines, one for each read/write operation (stdin r/w, socket r/w)
Inter-thread cooperations is possible through the use of synchronization points, lwt maiboxes (`Lwt_mvar.t`)

Here is a schema representing the behavior of the different routines.

![Lwt schema](res/lwt_schema.png)

### Ui

All the messages stored are printed when the state changes (message or aack received).

### Improvements possible

* A DB for more messages
* A true TTY input field
* Encode message in binary instead of plain text
