describe 'NodeController', ->

  beforeEach module 'app'

  controller = scope = http = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    config =
      get: (attr) ->
        {baseurl: ''}[attr]
    scope = $rootScope.$new();
    routeParams =
      id: '5'
    data = '{"id":"5","properties":{"site":"chidc1"}}'
    http = _$httpBackend_
    http.expectGET("/devices/#{routeParams.id}").respond(data);
    controller = $controller NodeController,
      $scope: scope,
      $routeParams: routeParams
      config: config

  it 'should attach the devices to the $scope', ->
    http.flush()
    expect(JSON.stringify(scope.device)).toEqual data


