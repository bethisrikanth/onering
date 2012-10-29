(function() {

  describe('NodeController', function() {
    var controller, data, http, routeParams, scope;
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function($controller) {
      scope = {};
      routeParams = {
        id: '5'
      };
      data = '7';
      http = jasmine.createSpy('http').andReturn({
        success: function(callback) {
          return callback(data);
        }
      });
      return controller = $controller('NodeController', {
        $scope: scope,
        $http: http,
        $routeParams: routeParams
      });
    }));
    it('should call the API /devices/#{scope.id}', function() {
      return expect(http).toHaveBeenCalledWith({
        method: 'GET',
        url: "/devices/" + scope.id
      });
    });
    return it('should attach the devices to the $scope', function() {
      return expect(scope.device).toEqual(data);
    });
  });

}).call(this);
