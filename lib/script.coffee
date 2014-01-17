$ = require 'riotjs'
domify = require 'domify'

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
exports.link = (bindings, selctors) ->
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
exports.commit = (elem, committer) ->
