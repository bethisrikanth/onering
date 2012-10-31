(function() {

  describe('DeviceSummaryController', function() {
    var controller, data, http, routeParams, scope;
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function(_$httpBackend_, $rootScope, $controller) {
      scope = $rootScope.$new();
      routeParams = {
        field: 'f'
      };
      data = '123';
      http = _$httpBackend_;
      http.expectGET("/devices/summary/by-" + routeParams.field).respond(data);
      return controller = $controller(DeviceSummaryController, {
        $scope: scope,
        $routeParams: routeParams
      });
    }));
    it('should attach the summary to the $scope', function() {
      http.flush();
      return expect(scope.summary).toEqual(data);
    });
    return it('should set $scope.orderProp to total', function() {
      return expect(scope.orderProp).toEqual('total');
    });
  });

}).call(this);
