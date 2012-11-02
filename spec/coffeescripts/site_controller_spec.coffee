describe 'SiteController', ->

  controller = scope = http = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    config =
      get: (attr) ->
        {baseurl: ''}[attr]
    scope = $rootScope.$new()
    routeParams =
      site: 's'
    data = '123'
    http = _$httpBackend_
    http.expectGET("/devices/find/site/#{routeParams.site}").respond(data);
    controller = $controller SiteController,
      $scope: scope,
      $routeParams: routeParams
      config: config

  it 'should attach the devices to the $scope', ->
    http.flush()
    expect(scope.devices).toEqual data
