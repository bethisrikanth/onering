describe 'DefaultController', ->
  controller = null

  beforeEach ->
    controller = new DefaultController()

  it 'should not be null', ->
    expect(controller).not.toBe null

describe 'QueryController', ->

  queryController = scope = http = route = routeParams = data = null

  # Initialize the controller and a mock scope
  beforeEach inject ($controller) ->
    scope = {}
    routeParams =
      field: 'f'
      query: 'q'
    route =
      current:
        $route:
          params: {}
    data = '123'
    http = jasmine.createSpy('http').andReturn
      success: (callback) -> callback(data)
    queryController = $controller 'QueryController',
      $scope: scope,
      $http: http,
      $route: route,
      $routeParams: routeParams

  it 'should call the API /devices/find/', ->
    expect(http).toHaveBeenCalledWith
      method: 'GET'
      url: "/devices/find/#{scope.field}/#{scope.query}"

  it 'should attach the devices to the $scope', ->
    expect(scope.devices).toEqual data