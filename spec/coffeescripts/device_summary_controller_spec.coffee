describe 'DeviceSummaryController', ->

  beforeEach module 'app'

  controller = scope = http = routeParams = data = null

  beforeEach inject (_$httpBackend_, $rootScope, $controller) ->
    config =
      get: (attr) ->
        {baseurl: ''}[attr]
    scope = $rootScope.$new()
    routeParams =
      field: 'f'
    data = '[{"id":"ladc1","count":3,"children":[{"id":null,"count":3,"children":[{"id":null,"count":3}]}]}]'
    http = _$httpBackend_
    http.expectGET("/devices/summary/by-#{routeParams.field}").respond(data);
    controller = $controller DeviceSummaryController,
      $scope: scope,
      $routeParams: routeParams,
      config: config

  it 'should attach the summary to the $scope', ->
    http.flush()
    expect(JSON.stringify(scope.summary)).toEqual data

  it 'should set $scope.orderProp to total', ->
    expect(scope.orderProp).toEqual 'total'