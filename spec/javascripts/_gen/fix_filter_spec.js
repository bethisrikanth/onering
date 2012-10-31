(function() {

  describe('fix filter', function() {
    beforeEach(module('filters'));
    it('0 should be "0"', inject(function(fixFilter) {
      return expect(fixFilter('0')).toEqual('0');
    }));
    return it('1 should be "1.50" (fixed=2)', inject(function(fixFilter) {
      return expect(fixFilter('1.5', 2)).toEqual('1.50');
    }));
  });

}).call(this);
