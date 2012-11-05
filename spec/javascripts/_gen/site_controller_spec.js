(function() {

  describe('SiteController', function() {
    var controller, data, http, routeParams, scope;
    beforeEach(module('app'));
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
        site: 's'
      };
      data = ['123'];
      http = _$httpBackend_;
      http.expectGET("/devices/summary/by-site/rack/model/?where=site/" + routeParams.site).respond(data);
      return controller = $controller(SiteController, {
        $scope: scope,
        $routeParams: routeParams,
        config: config
      });
    }));
    return it('should attach the devices to the $scope', function() {
      http.flush();
      return expect(scope.summary).toEqual(data[0]);
    });
  });

}).call(this);
