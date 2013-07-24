angular.module('automationRoutes', ['ng']).
config(['$routeProvider', function($routeProvider){
  $routeProvider.
  when('/automation', {
    templateUrl: 'views/automation.html',
    controller:  AutomationController
  });
}]);