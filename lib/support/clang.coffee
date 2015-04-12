{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'

module.exports =
  # Finds the clang_complete file by recursing up to parents.
  findCompleteFile: (searchdir, cb) ->
    searchfile = path.join searchdir, '.clang_complete'
    fs.stat searchfile, (err, searchfilestats) =>
      if searchfilestats? and searchfilestats.isFile()
        fs.readFile searchfile, 'utf8', (err, contents) =>
          cb err, searchdir, contents
      else
        parentdir = path.dirname searchdir
        return @findCompleteFile parentdir, cb unless parentdir is searchdir
        return cb null, null, null

  # Creates default configuration for the specified file path.
  createDefaultConfiguration: (options, cb) ->
    @findCompleteFile path.dirname(options.filename), (err, searchdir, contents) ->
      cb err if err?
      options.std ?= 'c++11'
      options.includes ?= []
      options.args ?= []
      for arg in (contents ? '').split('\n') when arg isnt ''
        if arg.match /^-I./
          options.includes.push arg.replace(/^-I/, '')
        else
          options.args.push arg
      cb()

  getCompletions: (options, cb) ->
    work = (err) =>

      args = ['-fsyntax-only', "-x#{options.lang ? 'c++'}", '-Xclang']
      args.push "-code-completion-at=-:#{options.position.row + 1}:#{options.position.column + 1}"
      args.push "-std=#{options.std}" if options.std?
      (args.push "-I#{include}" for include in options.includes) if options.includes?
      args = args.concat options.args if options.args?
      args.push '-' if options.text?

      cwd = options.cwd ? path.dirname(options.filename)
      command = options.command ? 'clang'
      console.log args
      proc = spawn command, args, {cwd: cwd, stdio: ['pipe', 'pipe', 'pipe']}

      stdoutstring = ''
      proc.stdout.setEncoding 'utf8'
      proc.stderr.setEncoding 'utf8'
      proc.on 'exit', (code) =>
        code = null if code? is 0
        cb code, @parseCompletions(stdoutstring)
        proc.kill
      proc.on 'error', (err) ->
        cb err
      proc.stdout.on 'data', (data) ->
        stdoutstring += data
      proc.stderr.on 'data', (data) ->
        console.log data

      if options.text?
        proc.stdin.write options.text
        proc.stdin.end()
      else
        fs.readFile options.filename, 'utf8', (err, contents) ->
          if err
            proc.kill()
            cb err
          else
            proc.stdin.write contents
            proc.stdin.end()

    if options.automaticDefaults
      @createDefaultConfiguration options, work
    else
      work()

  parseCompletions: (completions) ->
    results = []
    for descriptor in completions.trim().split('\n')
      continue unless descriptor?
      continue unless descriptor.match /^COMPLETION:\ /
      descriptor = descriptor.replace(/^COMPLETION:\ /, '').trim()

      description = (descriptor.match /^.*?\ :/)
      return null unless description
      description = description[0]

      description = description.replace /\ :$/, ''
      descriptor = descriptor.replace /^.*?\ :\ /, ''

      result = null
      if descriptor.match /::$/
        result =
          description: description
          descriptor: descriptor
          returntype: null
          type: 'ns'
      else
        # Get the return type if it exists
        returntype = descriptor.match /^\[#(.*?)#\]/
        returntype = returntype[1] if returntype?
        descriptor = descriptor.replace /\[#(.*?)#\]/g, ''

        # Convert to snippet format
        i = 0
        descriptor = descriptor.replace /<#(.*?)#>|{#(.*?)#}/g, (match, p1, p2) ->
          ++i
          "${#{i}:#{p1 or p2}}"

        type = 'f'
        type = 'm' if descriptor.match /\)$/

        result =
          description: description
          descriptor: descriptor
          returntype: returntype
          type: type
      results.push result
    results
