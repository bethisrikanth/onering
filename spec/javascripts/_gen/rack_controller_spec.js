(function() {

  describe('RackController', function() {
    var controller, data, http, routeParams, scope;
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function(_$httpBackend_, $rootScope, $controller) {
      var config;
      config = {
        get: function(attr) {
          return {
            baseurl: ''
          }[attr];
        }
      };
      scope = $rootScope.$new();
      routeParams = {
        site: 's',
        rack: 'r'
      };
      data = '123';
      http = _$httpBackend_;
      http.expectGET("/devices/find/site/" + routeParams.site + "/model/" + routeParams.rack).respond(data);
      return controller = $controller(RackController, {
        $scope: scope,
        $routeParams: routeParams,
        config: config
      });
    }));
    return it('should attach the devices to the $scope', function() {
      http.flush();
      return expect(scope.devices).toEqual(data);
    });
  });

}).call(this);
