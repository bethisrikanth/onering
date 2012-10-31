describe 'fix filter', () ->
  beforeEach module 'filters'

  it '0 should be "0"', inject (fixFilter) ->
    expect(fixFilter('0')).toEqual('0')

  it '1 should be "1.50" (fixed=2)', inject (fixFilter) ->
    expect(fixFilter('1.5', 2)).toEqual('1.50')
