Clang = require '../../lib/support/clang'

describe "Clang", ->

  describe "when completions are parsed", ->
    it "parses completions to the correct values", ->
      [completions] = []

      streamdata = '''
COMPLETION: namespace : namespace::
COMPLETION: getint : [#const int#]getint<<#T#>>(<#string myarg#>, <#int secondarg#>)
COMPLETION: aclass : aclass<<#T#>>
COMPLETION: afield : afield
'''
      runs ->
        completions = Clang.parseCompletions streamdata
        expect(completions).toBeDefined()
        expect(completions.length).toBe 4
        expect(completions[0]).toEqual
          description: "namespace"
          descriptor: "namespace::"
          returntype: null
          type: 'ns'
        expect(completions[1]).toEqual
          description: 'getint'
          descriptor: 'getint<${1:T}>(${2:string myarg}, ${3:int secondarg})'
          returntype: 'const int'
          type: 'm'
        expect(completions[2]).toEqual
          description: 'aclass'
          descriptor: 'aclass<${1:T}>'
          returntype: null
          type: 'f'
        expect(completions[3]).toEqual
          description: 'afield'
          descriptor: 'afield'
          returntype: null
          type: 'f'
