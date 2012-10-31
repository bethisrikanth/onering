describe 'filter', () ->
  beforeEach module 'filters'

  describe 'titleize', () ->

    it 'should say Hello', inject (titleizeFilter) ->
      expect(titleizeFilter('hello')).toEqual('Hello')

    it 'should titleize hello_world', inject (titleizeFilter) ->
      expect(titleizeFilter('hello_world')).toEqual('Hello World')

    it 'should titleize hello world 123', inject (titleizeFilter) ->
      expect(titleizeFilter('hello world 123')).toEqual('Hello World 123')
