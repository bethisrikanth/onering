describe 'NodeController', ->

  controller = scope = http = routeParams = data = null

  # Initialize the controller and a mock scope
  beforeEach inject ($controller) ->
    scope = {}
    routeParams =
      id: '5'
    data = '7'
    http = jasmine.createSpy('http').andReturn
      success: (callback) -> callback(data)
    controller = $controller 'NodeController',
      $scope: scope,
      $http: http,
      $routeParams: routeParams

  it 'should call the API /devices/#{scope.id}', ->
    expect(http).toHaveBeenCalledWith
      method: 'GET'
      url: "/devices/#{scope.id}"

  it 'should attach the devices to the $scope', ->
    expect(scope.device).toEqual data
