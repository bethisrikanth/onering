'use strict';

/* jasmine specs for filters go here */

describe('filter', function() {
  beforeEach(module('filters'));

  describe('titleize', function() {
    // beforeEach(module(function($provide) {
    //   $provide.value('version', 'TEST_VER');
    // }));


    it('should say Hello', inject(function(titleizeFilter) {
      expect(titleizeFilter('hello')).toEqual('Hello');
    }));
    it('should titleize hello_world', inject(function(titleizeFilter) {
      expect(titleizeFilter('hello_world')).toEqual('Hello World');
    }));
    it('should titleize hello world 123', inject(function(titleizeFilter) {
      expect(titleizeFilter('hello world 123')).toEqual('Hello World 123');
    }));
  });
});