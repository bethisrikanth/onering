(function() {

  describe('autospeed filter', function() {
    beforeEach(module('filters'));
    it('0 should be "0 Hz"', inject(function(autospeedFilter) {
      return expect(autospeedFilter('0')).toEqual('0 Hz');
    }));
    it('1500 should be "1.5 KHz"', inject(function(autospeedFilter) {
      return expect(autospeedFilter('1500')).toEqual('1.5 KHz');
    }));
    return it('1000000 should be "1 MHz"', inject(function(autospeedFilter) {
      return expect(autospeedFilter('1000000')).toEqual('1 MHz');
    }));
  });

}).call(this);
