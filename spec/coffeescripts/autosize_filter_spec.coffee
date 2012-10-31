describe 'autosize filter', () ->
  beforeEach module 'filters'

  it '0 should be "0 bytes"', inject (autosizeFilter) ->
    expect(autosizeFilter('0')).toEqual('0 bytes')

  it '1 should be "1 bytes"', inject (autosizeFilter) ->
    expect(autosizeFilter('1')).toEqual('1 bytes')

  it '1048576 should be "1.00 KiB"', inject (autosizeFilter) ->
    expect(autosizeFilter('1048576')).toEqual('1.00 KiB')

  it '1073741824 should be "1.00 GiB"', inject (autosizeFilter) ->
    expect(autosizeFilter('1073741824')).toEqual('1.00 GiB')
