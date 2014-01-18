$ = require 'riotjs'
domify = require 'domify'

# Create an instance of the DOM manager
#
# @param {Element} rootElem The element to be managed
exports.create = (rootElem) ->
  # Queue all DOM operations
  #
  # @private
  # @type Array.<Function>
  queue = []

  # Helper function to `commit(2)` to flush the queue and to commit the DOM
  # changes when we're at the end of the run-loop. This works by calling itself
  # with a `setTimeout(2)`.
  #
  # `runloop(0)` would continue to call itself asynchronously until the queue is
  # empty. Because arbitrary code can run in `commit(2)`, there may be
  # additional immediate `setTimeout(2)`s (i.e. `window.setTimeout(0);`)
  # triggered before we want to commit to DOM. Therefore, we want to call
  # `runloop(0)` again at the *end* with a `setTimeout(2)` to check again.
  #
  # @private
  # @function
  runloop = ->
    # Stop if the queue is empty
    return if queue.length is 0
    # Copy over the queue and clear the old one
    _queue = queue
    queue = []
    # Run everything in the queue
    callback() for callback in _queue
    # Make sure we're at the end
    setTimeout ->
      if queue.length is 0
        # If there's truly no more, commit to DOM
        commitToDom()
      else
        # Empty the queue again otherwise
        runloop()
    , 0

  # Commit the phantom DOM to document
  #
  # @private
  # @function
  commitToDom = ->


  # The following is the returned object

  # Compile an HTML string into a bindings object with the values as DOM
  # elements. This always returns an object containing a `root` pointing to the
  # root DOM element represented in the HTML string.
  #
  # The bindings object is turned into an observable, using
  # [Riot.js](https://github.com/moot/riotjs) specifically.
  #
  # @param {string} template An HTML string to compile
  # @returns {Object.<string, Element>} The bindings object
  compile: (template) ->
    $.observable
      root: domify template

  # Link additional DOM elements given a bindings object by specifying class
  # names
  #
  # @param {Object.<string, Element>} bindings The bindings object
  # @param {Object.<string, Array.<string>>} selectors Selectors that set up
  #   references to the DOM elements pointed to by an array of class names, each
  #   of which is passed to `getElementByClassName(1)`
  # @returns {Object.<string, Element>} The bindings object
  link: (bindings, selctors) ->
    # Go through each selector
    for name, classes of selectors
      # Do not interfere with root
      continue if name is 'root'

      # Reset the reference point to root for a new search
      ref = bindings.root

      # Each selector is an array of classes
      for _class in classes
        # Each level is passed to `getElementByClassName`
        ref = ref.getElementByClassName _class

      # Commit the reference point
      bindings.name = ref

    # Return the new bindings
    bindings

  # Commit DOM element in batches
  #
  # @param {Element} elem A DOM element
  # @param {Function} committer A function to be called when the element is ready
  #   to be committed
  commit: (elem, committer) ->
    # Save the DOM execution
    queue.push -> committer elem
    # Then start the run-loop at the end of this cycle
    setTimeout runloop, 0
