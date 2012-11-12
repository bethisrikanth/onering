(function() {

  describe('RackController', function() {
    var controller, data, http, routeParams, scope;
    beforeEach(module('app'));
    controller = scope = http = routeParams = data = null;
    beforeEach(inject(function(_$httpBackend_, $rootScope, $controller) {
      scope = $rootScope.$new();
      routeParams = {
        site: 's',
        rack: 'r'
      };
      data = '[{"id":null,"count":1,"children":[{"id":"mem-10000-prod-nydc1.nydc1.outbrain.com","count":1}]}]';
      http = _$httpBackend_;
      http.expectGET("/api/devices/summary/by-unit/fqdn/?where=site/" + routeParams.site + "/rack/" + routeParams.rack).respond(data);
      return controller = $controller(RackController, {
        $scope: scope,
        $routeParams: routeParams
      });
    }));
    return it('should attach the devices to the $scope', function() {
      http.flush();
      return expect(JSON.stringify(scope.devices)).toEqual(data);
    });
  });

}).call(this);
