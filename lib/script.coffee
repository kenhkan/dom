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

# The root DOM element. At the end of the run-loop, we would detach this DOM
# from the document's DOM and re-insert it after flushing the queued-up DOM
# operation.
#
# @private
# @type Element
rootDom = null

# Call count of run-loop. Only commit when it's the last call of the run-loop.
#
# The run-loop with this call count works like garbage collection and reference
# counting.
#
# @private
# @type number
runLoopCallCount = 0


# The run-loop flushes the queue and to commit the DOM changes when we're at
# the end of the run-loop.
#
# @private
# @function
runLoop = ->
  # Decrement call count no matter what
  runLoopCallCount--
  # Stop if the queue is already empty
  return if queue.length is 0
  # Also stop when we're not at the end yet (i.e. there is still pending call)
  return if runLoopCallCount > 0

  # Detach root from document
  rootParentDom = rootDom.parent
  rootNextSiblingDom = rootDom.nextSibling
  rootParentDom.removeChild rootDom

  # Flush all DOM operations
  flushDom()

  # Re-attach root to document after DOM operations
  rootParentDom.insertBefore rootDom, rootNextSiblingDom

# Flush pending DOM operations. This does so recursively as the callbacks may
# induce more DOM operations.
#
# @private
# @function
flushDom = ->
  # Obviously stop if there's no more to flush
  return if queue.length is 0

  # Copy over the queue and clear the old one. We must do this before the
  # callback invocations below because the callbacks may add to the queue by
  # committing additional DOM operations
  _queue = queue
  queue = []

  # Run everything in the queue
  callback() for callback in _queue

  # Continuously flush
  flushDom()

# Wrap a DOM element in a function that yields the element (or elements
# individually) that only gets run at the end of the run-loop.
#
# @private
# @param {Array.<Element>} elements DOM elements to conceal
# @returns {function} A function that yields the element in the run-loop
wrapElements = (elements) ->
  # This function is called with the function that actually executes the DOM
  # operation so the parameter function needs access to the DOM element as a
  # parameter and as the context
  (operator) ->
    # Save the DOM execution
    queue.push ->
      # Actually operate on the DOM elements
      for element in elements
        operator.call element, element

    # Increment the call count
    runLoopCallCount++
    # Then start the run-loop at the end
    setTimeout runLoop, 0

# Helper function to bind 
#
# @private
# @param {Object.<string, function>} bindings The bindings object
# @param {string} key The name of the binding
# @param value The bound value
setBinding = (bindings, key, value) ->
  # Should not be able to bind to already bound key
  if bindings[key]?
    throw new Error "#{key} is already bound"

  # OK to bind
  bindings[key] = value

  # Return the bindings as protocol
  bindings


# Bootstrap the DOM manager on an element. Note that it is impossible to
# bootstrap on two DOM trees on a page. Calling `bootstrap(1)` twice would
# un-manage the first DOM tree.
#
# The best strategy is to bootstrap on `document.body`. If that is not
# possible, bootstrap on the common ancester of all the relevant DOM elements
# that you're interested in manipulating.
#
# @param {Element} dom The DOM element to be managed. You should _never_
#   touch the DOM after handing over control to `pixbi/dom` as some changes
#   would be lost
exports.bootstrap = (dom) ->
  if document is dom
    throw new Error 'You may not bootstrap on the document itself, try `document.body` instead'

  # Save the DOM for committing
  rootDom = dom

# Compile an HTML string into a bindings object with the values as DOM
# elements. This always returns an object containing a `root` pointing to the a
# binding function that resolves to the root DOM element represented in the
# HTML string.
#
# The bindings object itself is turned into an observable, using
# [Riot.js](https://github.com/moot/riotjs) specifically.
#
# @param {string} template An HTML string to compile
# @returns {Object.<string, Element>} The bindings object
exports.compile = (template) ->
  # Make a bindings object that is observable
  $.observable
    # Convert template string into DOM elements
    root: wrapElements [domify template]

# Bind additional DOM elements given a bindings object by specifying class
# names.
#
# You want to use `bind(2)` instead of looking up the element with, say, jQuery
# because you only pay the heavy price of DOM traversal once at the binding
# stage. This function also uses the native `getElementsByClassName(1)`, which
# is much faster than the alternatives.
#
# @param {Object.<string, function>} bindings The bindings object
# @param {Object.<string, string>} selectors Selectors that set up
#   references to the DOM elements
# @returns {Object.<string, function>} The bindings object
exports.bind = (bindings, selctors) ->
  # Go through each selector
  for name, selector of selectors
    # Do not interfere with root
    continue if name is 'root'

    # Start with root
    refs = [bindings.root]

    # Iterate through each level of the selector
    for level in selector.split ' '
      # Get rid of the dots for `getElementsByClassName(1)`
      #   e.g. '.div.class.whatever' => 'div class whatever'
      level = level.replace(/\./g, ' ')[1..]
      # Each level is passed to `getElementsByClassName(1)`
      refs = (ref.getElementsByClassName(level) for ref in refs)

    # Commit the reference points
    setBinding bindings, name, wrapElements refs

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
    _components: ".#{COMPONENT_CLASS_NAME}"

  # Go through each component
  for componentElement in bindings._components
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
    setBinding bindings, name, instanceBindings
    # Replace the declaration DOM with the DOM of the instance in the linking
    # component's own DOM tree
    component.parentNode.insertBefore instanceBindings.root, componentElement
    component.parentNode.removeChild componentElement

  # Clean the bindings up of the old component elements
  delete bindings._components

  # Return the updated bindings object
  bindings
