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
    });
  });

  describe('device summary page', function(){
    it('should bind :field to xxx', function() {
      browser().navigateTo('/index.html#/inf/summary/xxx')
      expect(binding('field')).toBe('xxx');
    });
    it('by default it should should bind :field to "site"', function() {
      browser().navigateTo('/index.html#/inf/summary/')
      expect(binding('field')).toBe('site');
    });
  });

  // describe('node details page', function(){
  //   beforeEach(function(){
  //     browser().navigateTo('/index.html#/node/5')
  //   });
  //   it('should bind :id to 5', function() {
  //     expect(binding('id')).toBe('5');
  //   });
  // });

  // describe('rack page', function(){
  //   beforeEach(function(){
  //     browser().navigateTo('/index.html#/site/siteX/rackY')
  //   });
  //   it('should bind path variables', function() {
  //     expect(binding('site')).toBe('siteX');
  //     expect(binding('rack')).toBe('rackY');
  //   });
  // });
});
