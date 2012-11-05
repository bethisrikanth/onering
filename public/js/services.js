'use strict';

/* Services */

var app = angular.module('oneringServices', ['ngResource']);

app.factory('Device', function($resource) {
  return $resource('/devices/:id', {id: '@id'});
});

app.factory('DeviceSummary', function($resource) {
  return $resource('/devices/summary/by-:field', {field: 'site'});
});
