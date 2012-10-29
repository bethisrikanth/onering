(function() {

  describe('DeviceSummaryController', function() {
    var controller, data, http, routeParams, scope;
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function($controller) {
      scope = {};
      routeParams = {
        field: 'f',
        query: 'q'
      };
      data = '123';
      http = jasmine.createSpy('http').andReturn({
        success: function(callback) {
          return callback(data);
        }
      });
      return controller = $controller('DeviceSummaryController', {
        $scope: scope,
        $http: http,
        $routeParams: routeParams
      });
    }));
    it('should call the API /devices/summary/by-#{scope.field}', function() {
      return expect(http).toHaveBeenCalledWith({
        method: 'GET',
        url: "/devices/summary/by-" + scope.field
      });
    });
    it('should attach the summary to the $scope', function() {
      return expect(scope.summary).toEqual(data);
    });
    return it('should set $scope.orderProp to total', function() {
      return expect(scope.orderProp).toEqual('total');
    });
  });

}).call(this);
