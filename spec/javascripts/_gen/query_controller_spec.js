(function() {

  describe('QueryController', function() {
    var data, http, queryController, route, routeParams, scope;
    beforeEach(module('app'));
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
        query: 'f/q'
      };
      route = {
        current: {
          $route: {
            params: {}
          }
        }
      };
      data = '[{"id":"chidc1","count":2},{"id":"ladc1","count":3},{"id":"nydc1","count":1}]';
      http = _$httpBackend_;
      http.expectGET("/api/devices/find/").respond(data);
      return queryController = $controller(QueryController, {
        $scope: scope,
        $route: route,
        $routeParams: routeParams,
        config: config
      });
    }));
    return it('should attach the devices to the $scope', function() {
      http.flush();
      return expect(JSON.stringify(scope.devices)).toEqual(data);
    });
  });

}).call(this);
