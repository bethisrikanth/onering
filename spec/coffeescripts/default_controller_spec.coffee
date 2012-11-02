describe 'DefaultController', ->
  controller = null

  beforeEach inject ($rootScope, $controller) ->
    scope = $rootScope.$new();
    controller = $controller DefaultController,
      $scope: scope

  it 'should not be null', ->
    expect(controller).not.toBe null

