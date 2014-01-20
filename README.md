# Sensible DOM manipulation

`pixbi/dom` assumes control of your entire document DOM or parts of it. You
pass in a DOM element whose content you want `pixbi/dom` to manage. The content
is managed in a run-loop for maximum performance. All changes made within
`commit(2)` are batched up and committed at the end of the run-loop, at which
point `pixbi/dom` commits all the change to the phantom DOM and write the
updated phantom DOM as the `innerHTML` of the element that was passed to
`pixbi/dom`.
