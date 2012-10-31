(function() {

  describe('filter', function() {
    beforeEach(module('filters'));
    return describe('titleize', function() {
      it('should say Hello', inject(function(titleizeFilter) {
        return expect(titleizeFilter('hello')).toEqual('Hello');
      }));
      it('should titleize hello_world', inject(function(titleizeFilter) {
        return expect(titleizeFilter('hello_world')).toEqual('Hello World');
      }));
      return it('should titleize hello world 123', inject(function(titleizeFilter) {
        return expect(titleizeFilter('hello world 123')).toEqual('Hello World 123');
      }));
    });
  });

}).call(this);
