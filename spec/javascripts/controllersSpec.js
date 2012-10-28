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

describe('QueryController', function() {

  var QueryController, scope, http, route, routeParams, data;

  // Initialize the controller and a mock scope
  beforeEach(inject(function($controller) {
    scope = {};
    routeParams = {field: 'f', query: 'q'};
    route = {current: {
       $route: {
         params: {}}}};
    data = "123";
    http = jasmine.createSpy('http').andReturn({success: function(callback){callback(data)}});
    // http = function(){return {success: function(callback){callback(data)}}};
    QueryController = $controller('QueryController', {
      $scope: scope,
      $http: http,
      $route: route,
      $routeParams: routeParams
    });
  }));

  it('should call the API /devices/find/', function() {
    expect(http).toHaveBeenCalledWith({method: 'GET', url: '/devices/find/' + scope.field + '/' + scope.query});
  });
  it('should attach the devices to the $scope', function() {
    expect(scope.devices).toEqual(data);
  });
});