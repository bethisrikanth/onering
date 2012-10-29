(function() {

  describe('RackController', function() {
    var controller, data, http, routeParams, scope;
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function($controller) {
      scope = {};
      routeParams = {
        site: 's',
        rack: 'r'
      };
      data = '123';
      http = jasmine.createSpy('http').andReturn({
        success: function(callback) {
          return callback(data);
        }
      });
      return controller = $controller('RackController', {
        $scope: scope,
        $http: http,
        $routeParams: routeParams
      });
    }));
    it('should call the API /devices/find/site/#{$scope.site}/model/#{$scope.rack}', function() {
      return expect(http).toHaveBeenCalledWith({
        method: 'GET',
        url: "/devices/find/site/" + scope.site + "/model/" + scope.rack
      });
    });
    return it('should attach the devices to the $scope', function() {
      return expect(scope.devices).toEqual(data);
    });
  });

}).call(this);
