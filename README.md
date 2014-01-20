# Sensible DOM manipulation

`pixbi/dom` assumes control of your entire document DOM or parts of it. You
pass in a DOM element whose content you want `pixbi/dom` to manage. The content
is managed in a count-based run-loop for maximum performance.

All DOM manipulation is made by invoking the binding function in the bindings
object as returned by `compile(1)`. Each time the binding function invoked, a
call is made to the run-loop _at the end of the event queue_, meaning that by
the time all calls to the run-loop are resolved, all DOM operations would have
been registered with the run-loop, at which point the run-loop flushes all DOM
operations.

If there is a managed DOM tree registered via `bootstrap(1)`, the DOM tree
would be detached from the document, DOM operations would be executed, and the
DOM tree is then re-attached to the DOM tree. Updating the DOM "offline" from
the live document is generally more performant than otherwise.

There is only one file (i.e. `lib/script.coffee`) and it is heavily commented.
The LoC is clocking only at around 100 lines. Reading through it should give
you a much better understanding of how it works.
