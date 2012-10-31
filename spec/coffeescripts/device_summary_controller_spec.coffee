describe 'DeviceSummaryController', ->

  controller = scope = http = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    config =
      get: (attr) ->
        {baseurl: ''}[attr]
    scope = $rootScope.$new()
    routeParams =
      field: 'f'
    data = '123'
    http = _$httpBackend_
    http.expectGET("/devices/summary/by-#{routeParams.field}").respond(data);
    controller = $controller DeviceSummaryController,
      $scope: scope,
      $routeParams: routeParams,
      config: config

  it 'should attach the summary to the $scope', ->
    http.flush()
    expect(scope.summary).toEqual data

  it 'should set $scope.orderProp to total', ->
    expect(scope.orderProp).toEqual 'total'