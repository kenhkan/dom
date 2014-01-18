pixbi/dom assumes control of your entire document DOM or parts of it. You pass
in a DOM element whose content you want pixbi/dom to manage. The content is
managed in a run-loop for maximum performance. All changes made within
`commit(2)` are batched up and committed at the end of the run-loop. At the end
of run-loop, pixbi/dom commits all the change to the phantom DOM and write the
updated DOM to the `innerHTML` of the element that is passed ot pixbi/dom.

pixbi/dom may manage multiple sub-nodes within your document. It exposes a
`create(1)` function that returns an object with the methods `compile(1)`,
`link(2)`, and `commit(2)`.
