(function() {

  describe('QueryController', function() {
    var data, http, queryController, route, routeParams, scope;
    queryController = scope = http = route = routeParams = data = null;
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
      http = _$httpBackend_;
      http.expectGET("/devices/find/" + routeParams.field + "/" + routeParams.query).respond(data);
      return queryController = $controller(QueryController, {
        $scope: scope,
        $route: route,
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
