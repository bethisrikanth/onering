(function() {

  describe('SummaryController', function() {
    var controller, data, http, routeParams, scope;
    beforeEach(module('app'));
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function(_$httpBackend_, $rootScope, $controller) {
      scope = $rootScope.$new();
      routeParams = {
        field: 'f'
      };
      data = '[{"id":"ladc1","count":3,"children":[{"id":null,"count":3,"children":[{"id":null,"count":3}]}]}]';
      http = _$httpBackend_;
      http.expectGET("/api/devices/summary/by-" + routeParams.field).respond(data);
      return controller = $controller(SummaryController, {
        $scope: scope,
        $routeParams: routeParams,
        $route: {
          current: {
            $route: {
              params: {}
            }
          }
        }
      });
    }));
    it('should attach the summary to the $scope', function() {
      http.flush();
      return expect(JSON.stringify(scope.summary)).toEqual(data);
    });
    return it('should set $scope.orderProp to total', function() {
      return expect(scope.orderProp).toEqual('total');
    });
  });

}).call(this);
