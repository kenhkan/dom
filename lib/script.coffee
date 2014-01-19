$ = require 'riotjs'
domify = require 'domify'

# The class name to search for components
#
# @private
# @constant
# @type string
COMPONENT_CLASS_NAME = 'component'

# Queue all DOM operations
#
# @private
# @type Array.<Function>
queue = []

# The phantom DOM tree contains our DOM that we manipulate. At the end of the
# run-loop, we would commit this DOM tree into the document's DOM.
#
# @private
# @type Element
phantomDom = null


# Bootstrap the DOM manager on an element. Note that it is impossible to
# bootstrap on two DOM trees on a page. Calling `bootstrap(1)` twice would
# un-manage the first DOM tree.
#
# The best strategy is to bootstrap on `document.body`. If that is not
# possible, bootstrap on the common ancester of all the relevant DOM elements
# that you're interested in manipulating.
#
# @param {Element} liveDom The DOM element to be managed. You should _never_
#   touch the DOM after handing over control to `pixbi/dom` as some changes
#   would be lost
exports.bootstrap = (liveDom) ->
  # Copy over what is there right now into the phantom DOM for future
  # manipulation
  phantomDom = (new DOMParser).parseFromString liveDom.innerHTML, 'text/xml'

# The run-loop flushes the queue and to commit the DOM changes when we're at
# the end of the run-loop. It works by continuously calling itself
# asynchronously until the queue is empty.
#
# Because arbitrary code can run in `commit(2)`, there may be additional
# immediate `setTimeout(2)`s (i.e. code triggering `window.setTimeout(0);`)
# triggered before we want to commit to DOM.  Therefore, we want to call
# `runloop(0)` again at the *end* with a `setTimeout(2)` to check for sure.
#
# @private
# @function
runloop = ->
  # No need to continue if the queue is already empty
  return if queue.length is 0

  # Copy over the queue and clear the old one. We must do this before the
  # callback invocations below because the callbacks may add to the queue by
  # committing additional DOM operations
  _queue = queue
  queue = []

  # Run everything in the queue
  callback() for callback in _queue

  # Make sure run-loop runs again at the end
  setTimeout runloop, 0


# Compile an HTML string into a bindings object with the values as DOM
# elements. This always returns an object containing a `root` pointing to the
# root DOM element represented in the HTML string.
#
# The bindings object is turned into an observable, using
# [Riot.js](https://github.com/moot/riotjs) specifically.
#
# @param {string} template An HTML string to compile
# @returns {Object.<string, Element>} The bindings object
exports.compile = (template) ->
  # Make a bindings object that is observable
  $.observable
    # Convert template string into DOM elements
    root: domify template

# Bind additional DOM elements given a bindings object by specifying class
# names
#
# @param {Object.<string, Element>} bindings The bindings object
# @param {Object.<string, Array.<string>>} selectors Selectors that set up
#   references to the DOM elements pointed to by an array of class names, each
#   of which is passed to `getElementByClassName(1)`
# @returns {Object.<string, Array.<Element>>} The bindings object
exports.bind = (bindings, selctors) ->
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

    # Commit the reference points
    bindings[name] ?= []
    bindings[name].push ref

  # Return the new bindings
  bindings

# Search a DOM tree as defined in the provided bindings object for components
# and link them to the bindings object as well as the DOM tree by doing the
# following:
#
#   1. Search for elements with class name `component`
#   2. Extract attributes `component-source` and `component-name`
#   3. A new instance of `component-source` component is created
#   4. The bindings object of the new instance is assigned to the provided
#      bindings object (i.e. this function's parameter) with the key of
#      `component-name`
#   5. The DOM tree created from it (i.e. the `root` of the instance's bindings
#      object) is injected in place of the definition of the component in the
#      DOM tree of the containing component
#
# This function returns the bindings object with references to the components
# added in the linking process.
#
# @param {Object.<string, Element>} The bindings object
# @returns {Object.<string, Element>} The bindings object with references to
#   the new instance
exports.link = (bindings) ->
  # There must be a `root` DOM element
  unless bindings.root
    throw new Error 'There must be a `root` property in the bindings object'
  unless bindings.root.getElementByClassName
    throw new Error 'The root property must be a DOM element'

  # Search for all components using an existing function
  exports.bind bindings,
    _components: [COMPONENT_CLASS_NAME]

  # Go through each component
  for componentElement in bindings.components
    # Extract the source and the name
    source = componentElement.getAttribute "#{COMPONENT_CLASS_NAME}-source"
    name = componentElement.getAttribute "#{COMPONENT_CLASS_NAME}-name"
    # Skip if there's no source or name
    continue unless source and name

    # Extract parameters
    try
      params = JSON.parse componentElement.getAttribute "#{COMPONENT_CLASS_NAME}-params"
    catch error
      params = {}

    # Instantiate
    instanceBindings = require(source).create params
    # Bind to the linking component
    bindings[name] = instanceBindings
    # Replace the declaration DOM with the DOM of the instance in the linking
    # component's own DOM tree
    component.parentNode.insertBefore instanceBindings.root, componentElement
    component.parentNode.removeChild componentElement

  # Clean the bindings up of the old component elements
  delete bindings._components

  # Return the updated bindings object
  bindings

# Commit DOM element in batches. We require the element and pass the same thing
# back to reserve the right to perform some additional operations on the
# element or wrap it around some function. It does not do anything to it
# currently but we may in the future.
#
# @param {Element} elem A DOM element
# @param {Function} committer A function to be called when the element is ready
#   to be committed
exports.commit = (elem, committer) ->
  # Save the DOM execution
  queue.push -> committer elem
  # Then start the run-loop at the end of this queue
  setTimeout runloop, 0
