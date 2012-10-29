(function() {

  describe('QueryController', function() {
    var data, http, queryController, route, routeParams, scope;
    queryController = scope = http = route = routeParams = data = null;
    beforeEach(inject(function($controller) {
      scope = {};
      routeParams = {
        field: 'f',
        query: 'q'
      };
      route = {
        current: {
          $route: {
            params: {}
          }
        }
      };
      data = '123';
      http = jasmine.createSpy('http').andReturn({
        success: function(callback) {
          return callback(data);
        }
      });
      return queryController = $controller('QueryController', {
        $scope: scope,
        $http: http,
        $route: route,
        $routeParams: routeParams
      });
    }));
    it('should call the API /devices/find/', function() {
      return expect(http).toHaveBeenCalledWith({
        method: 'GET',
        url: "/devices/find/" + scope.field + "/" + scope.query
      });
    });
    return it('should attach the devices to the $scope', function() {
      return expect(scope.devices).toEqual(data);
    });
  });

}).call(this);
