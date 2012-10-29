describe 'SiteController', ->

  controller = scope = http = routeParams = data = null

  # Initialize the controller and a mock scope
  beforeEach inject ($controller) ->
    scope = {}
    routeParams =
      field: 'f'
    data = '123'
    http = jasmine.createSpy('http').andReturn
      success: (callback) -> callback(data)
    controller = $controller 'SiteController',
      $scope: scope,
      $http: http,
      $routeParams: routeParams

  it 'should call the API /devices/find/site/#{scope.field}', ->
    expect(http).toHaveBeenCalledWith
      method: 'GET'
      url: "/devices/find/site/#{scope.field}"

  it 'should attach the devices to the $scope', ->
    expect(scope.devices).toEqual data
