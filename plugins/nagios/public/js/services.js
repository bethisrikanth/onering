'use strict';

angular.module('nagiosService', ['ngResource']).
factory('NagiosHost', function($resource){
  return $resource('/api/nagios/:id', {
    id: '@id'
  });
});