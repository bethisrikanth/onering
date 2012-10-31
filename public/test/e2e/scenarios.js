'use strict';

/* http://docs.angularjs.org/guide/dev_guide.e2e-testing */

describe('onering', function() {

  describe('homepage', function(){
    beforeEach(function(){
      browser().navigateTo('/index.html');
    });
    it('should load the home page', function() {
      expect(browser().location().url()).toBe('');
    });
    it('should say ONERING HOMEPAGE', function(){
      expect(element('body').text()).toMatch(/ONERING HOMEPAGE/);
    })
  });
});
