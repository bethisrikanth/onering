describe 'RackController', ->

  beforeEach module 'app'

  controller = scope = http = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    config =
      get: (attr) ->
        {baseurl: ''}[attr]
    scope = $rootScope.$new()
    routeParams =
      site: 's'
      rack: 'r'
    data = '123'
    http = _$httpBackend_
    http.expectGET("/api/devices/summary/by-unit/fqdn/?where=site/#{routeParams.site}/rack/#{routeParams.rack}").respond(data);
    controller = $controller RackController,
      $scope: scope,
      $routeParams: routeParams
      config: config

  it 'should attach the devices to the $scope', ->
    http.flush()
    expect(scope.devices).toEqual data
