'use strict';

/* jasmine specs for controllers go here */

describe('DefaultController', function(){
  var controller;

  beforeEach(function(){
    controller = new DefaultController();
  });


  it('should not be null', function() {
    expect(controller).not.toEqual(null)
  });
});
