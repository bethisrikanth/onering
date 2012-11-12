describe 'QueryController', ->

  beforeEach module 'app'

  queryController = scope = http = route = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    scope = $rootScope.$new()
    routeParams =
      query: 'f/q'
    route =
      current:
        $route:
          params: {}
    data = '[{"id":"chidc1","count":2},{"id":"ladc1","count":3},{"id":"nydc1","count":1}]'
    http = _$httpBackend_
    http.expectGET("/api/devices/find/?q=#{encodeURIComponent(routeParams.query)}").respond(data);
    queryController = $controller QueryController,
      $scope: scope,
      $route: route,
      $routeParams: routeParams

  it 'should attach the devices to the $scope', ->
    http.flush()
    expect(JSON.stringify(scope.devices)).toEqual data
