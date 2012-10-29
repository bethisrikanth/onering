describe 'RackController', ->

  controller = scope = http = routeParams = data = null

  # Initialize the controller and a mock scope
  beforeEach inject ($controller) ->
    scope = {}
    routeParams =
      site: 's'
      rack: 'r'
    data = '123'
    http = jasmine.createSpy('http').andReturn
      success: (callback) -> callback(data)
    controller = $controller 'RackController',
      $scope: scope,
      $http: http,
      $routeParams: routeParams

  it 'should call the API /devices/find/site/#{$scope.site}/model/#{$scope.rack}', ->
    expect(http).toHaveBeenCalledWith
      method: 'GET'
      url: "/devices/find/site/#{scope.site}/model/#{scope.rack}"

  it 'should attach the devices to the $scope', ->
    expect(scope.devices).toEqual data
