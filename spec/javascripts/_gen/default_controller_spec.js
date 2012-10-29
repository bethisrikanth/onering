(function() {

  describe('DefaultController', function() {
    var controller;
    controller = null;
    beforeEach(function() {
      return controller = new DefaultController();
    });
    return it('should not be null', function() {
      return expect(controller).not.toBe(null);
    });
  });

}).call(this);
