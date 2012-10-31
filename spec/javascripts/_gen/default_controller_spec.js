(function() {

  describe('DefaultController', function() {
    var controller;
    controller = null;
    beforeEach(inject(function($rootScope, $controller) {
      var scope;
      scope = $rootScope.$new();
      return controller = $controller(DefaultController, {
        $scope: scope
      });
    }));
    return it('should not be null', function() {
      return expect(controller).not.toBe(null);
    });
  });

}).call(this);
