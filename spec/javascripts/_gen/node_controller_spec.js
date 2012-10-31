(function() {

  describe('NodeController', function() {
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
        id: '5'
      };
      data = '7';
      http = _$httpBackend_;
      http.expectGET("/devices/" + routeParams.id).respond(data);
      return controller = $controller(NodeController, {
        $scope: scope,
        $routeParams: routeParams,
        config: config
      });
    }));
    return it('should attach the devices to the $scope', function() {
      http.flush();
      return expect(scope.device).toEqual(data);
    });
  });

}).call(this);
