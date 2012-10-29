describe 'DefaultController', ->
  controller = null

  beforeEach ->
    controller = new DefaultController()

  it 'should not be null', ->
    expect(controller).not.toBe null
