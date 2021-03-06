angular.module('nagiosService', ['ngResource']).
factory('NagiosHost', function($resource){
  return $resource('/api/nagios/:id', {
    id: '@id',
    severity: 'ignore'
  });
}).
factory('NagiosAlerts', function($resource){
  return $resource('/api/nagios/alerts', {
    severity: 'ignore'
  });
});
