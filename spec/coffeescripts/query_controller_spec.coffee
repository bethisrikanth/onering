describe 'QueryController', ->

  queryController = scope = http = route = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    config =
      get: (attr) ->
        {baseurl: ''}[attr]
    scope = $rootScope.$new()
    routeParams =
      field: 'f'
      query: 'q'
    route =
      current:
        $route:
          params: {}
    data = '123'
    http = _$httpBackend_
    http.expectGET("/devices/find/#{routeParams.field}/#{routeParams.query}").respond(data);
    queryController = $controller QueryController,
      $scope: scope,
      $route: route,
      $routeParams: routeParams
      config: config

  it 'should attach the devices to the $scope', ->
    http.flush()
    expect(scope.devices).toEqual data