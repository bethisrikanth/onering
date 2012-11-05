'use strict';

/* Services */

var app = angular.module('oneringServices', ['ngResource']);

/*
get: /devices/:id
find: /devices/find/:field/:query
*/
app.factory('Device', function($resource) {
  return $resource('/devices/:id/:field/:query', {id: '@id'},
    {
      find: {
        method: 'get',
        params: {id: 'find'},
        isArray: true
      }
    });
});

/*
query: /devices/summary/by-:field
*/
app.factory('DeviceSummary', function($resource) {
  return $resource('/devices/summary/by-:field', {field: 'site'});
});
