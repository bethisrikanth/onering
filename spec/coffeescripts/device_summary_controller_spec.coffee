describe 'DeviceSummaryController', ->

  controller = scope = http = routeParams = data = null

  # Initialize the controller and a mock scope
  beforeEach inject ($controller) ->
    scope = {}
    routeParams =
      field: 'f'
      query: 'q'
    data = '123'
    http = jasmine.createSpy('http').andReturn
      success: (callback) -> callback(data)
    controller = $controller 'DeviceSummaryController',
      $scope: scope,
      $http: http,
      $routeParams: routeParams

  it 'should call the API /devices/summary/by-#{scope.field}', ->
    expect(http).toHaveBeenCalledWith
      method: 'GET'
      url: "/devices/summary/by-#{scope.field}"

  it 'should attach the summary to the $scope', ->
    expect(scope.summary).toEqual data

  it 'should set $scope.orderProp to total', ->
    expect(scope.orderProp).toEqual 'total'