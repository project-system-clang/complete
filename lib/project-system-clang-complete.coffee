Clang = require './support/clang'
{CompositeDisposable} = require 'atom'

module.exports =
class ClangAutocompleteProvider
  selector: '.source.c, .source.cpp'
  disableForSelector: '.comment'
  providers: null
  subscriptions: null
  currentExecution: null
  tokenSource: 0

  constructor: ->
    @subscriptions = new CompositeDisposable
    @providers = []

  dispose: ->
    @subscriptions?.dispose()
    @subscriptions = null

  getProjectMetadataPromises: (request, metadata) ->
    promises = []
    for provider in @providers
      getProjectMetadata = provider.getProjectMetadata.bind provider
      promises.push Promise.resolve(getProjectMetadata request, metadata)
    promises

  isProviderRegistered: (provider) ->
    @providers.includes provider

  addProvider: (provider, apiVersion='2.0.0') ->
    return unless provider?
    return if @isProviderRegistered provider
    @providers.push provider
    @subscriptions.add provider  if provider.dispose?

  isKnownPrefix: (prefix) ->
    prefix.match(/::\w+$/) or
    prefix.match(/\-\>\w+$/) or
    prefix.match(/\.\w+$/) or
    prefix.match(/#\w+$/) or
    prefix.match(/\<\w+$/) or
    prefix.match(/\(\w+$/)

  createSuggestions: (completions, prefix) =>
    suggestions = []
    for completion in completions when completion.description.match(new RegExp("^#{prefix}", "i"))
      suggestions.push suggestion =
        text: completion.description
        snippet: completion.descriptor
        #leftLabel: completion.returntype
        type: switch completion.type
          when 'ns' then 'import'
          when 'm' then 'method'
          else 'value'
    suggestions

  getSuggestions: ({editor, bufferPosition, prefix}) ->
    line = editor.getTextInBufferRange [[bufferPosition.row, 0], bufferPosition]
    return null unless @isKnownPrefix(line)

    isKnownPrefix = @isKnownPrefix prefix
    buffer = editor.buffer
    filename = editor.getPath()

    endPosition = [bufferPosition.row, bufferPosition.column]
    endPosition[1] -= prefix.length unless isKnownPrefix

    # Re-use the promise while it is executing and for a
    # short while after
    token = ++@tokenSource
    newExecution =
      filename: filename
      position: endPosition
      token: token

    if @currentExecution?.filename is newExecution.filename and
       @currentExecution?.position[0] is newExecution.position[0] and
       @currentExecution?.position[1] is newExecution.position[1]
        if @currentExecution.timeout?
          clearTimeout @currentExecution.timeout
          @currentExecution.timeout = setTimeout =>
            @currentExecution = null if @currentExecution.token == token
          , 2000
        return @currentExecution.promise.then (suggestions) => @createSuggestions suggestions, prefix
    @currentExecution = newExecution

    request =
      editor: editor
    metadata =
      filename: filename
      automaticDefaults: true
      text: editor.getTextInBufferRange [[0, 0], endPosition]

    @currentExecution.promise = new Promise (resolve, error) =>
      Promise.all(@getProjectMetadataPromises(request, metadata)).then =>
        metadata.position =
          row: endPosition[0]
          column: endPosition[1]
        Clang.getCompletions metadata, (code, completions) =>
          if code? and code isnt 0
            console.log metadata.text
            error "unexpected code" + code
          else
            if @currentExecution
              @currentExecution.timeout = setTimeout =>
                @currentExecution = null if @currentExecution?.token == token
              , 2000
            resolve completions

    @currentExecution.promise.then (results) =>
      @createSuggestions results, prefix
    .catch (error) =>
      console.log error
      @currentExecution = null
