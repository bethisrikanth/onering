describe 'NodeController', ->

  controller = scope = http = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    scope = $rootScope.$new();
    routeParams =
      id: '5'
    data = '7'
    http = _$httpBackend_
    http.expectGET("/devices/#{routeParams.id}").respond(data);
    controller = $controller NodeController,
      $scope: scope,
      $routeParams: routeParams

  it 'should attach the devices to the $scope', ->
    http.flush()
    expect(scope.device).toEqual data


