(function() {

  describe('SiteController', function() {
    var controller, data, http, routeParams, scope;
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function($controller) {
      scope = {};
      routeParams = {
        field: 'f'
      };
      data = '123';
      http = jasmine.createSpy('http').andReturn({
        success: function(callback) {
          return callback(data);
        }
      });
      return controller = $controller('SiteController', {
        $scope: scope,
        $http: http,
        $routeParams: routeParams
      });
    }));
    it('should call the API /devices/find/site/#{scope.field}', function() {
      return expect(http).toHaveBeenCalledWith({
        method: 'GET',
        url: "/devices/find/site/" + scope.field
      });
    });
    return it('should attach the devices to the $scope', function() {
      return expect(scope.devices).toEqual(data);
    });
  });

}).call(this);
