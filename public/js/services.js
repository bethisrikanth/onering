'use strict';

/* Services */

// var app = angular.module('app', ['filters']);
angular.module('oneringServices', ['ngResource']).factory('Device', function($resource){
  return $resource('/devices/:id', {id: '@id'});
});
