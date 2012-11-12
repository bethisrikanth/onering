describe 'RackController', ->

  beforeEach module 'app'

  controller = scope = http = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    scope = $rootScope.$new()
    routeParams =
      site: 's'
      rack: 'r'
    data = '[{"id":null,"count":1,"children":[{"id":"mem-10000-prod-nydc1.nydc1.outbrain.com","count":1}]}]'
    http = _$httpBackend_
    http.expectGET("/api/devices/summary/by-unit/fqdn/?where=site/#{routeParams.site}/rack/#{routeParams.rack}").respond(data);
    controller = $controller RackController,
      $scope: scope,
      $routeParams: routeParams

  it 'should attach the devices to the $scope', ->
    http.flush()
    expect(JSON.stringify(scope.devices)).toEqual data
