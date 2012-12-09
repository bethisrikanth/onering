angular.module('nagiosRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/alerts/nagios', {
    templateUrl: 'views/nagios-alert-list.html',
    controller:  NagiosAlertListController
  });
}]);
