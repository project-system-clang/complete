{CompositeDisposable} = require 'atom'

module.exports =
  activate: (state) ->

  serialize: ->

  deactivate: ->
    @autocompleteProvider?.dispose()
    autocompleteProvider = null

  getAutocompleteProvider: ->
    unless @autocompleteProvider?
      ClangAutocompleteProvider = require './project-system-clang-complete'
      @autocompleteProvider = new ClangAutocompleteProvider()
    @autocompleteProvider

  consumeProjectProvider: (providers, apiVersion = '2.0.0') ->
    providers = [providers] if providers? and not Array.isArray(providers)
    return unless providers?.length > 0
    registrations = new CompositeDisposable
    for provider in providers
      registrations.add @getCompletion().addProvider(provider, apiVersion)
    registrations
