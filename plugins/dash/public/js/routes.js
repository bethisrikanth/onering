angular.module('dashRoutes', ['ng']).
config(['$routeProvider', function($routeProvider){
  $routeProvider.
  when('/dash/test', {
    templateUrl: 'views/dash-test.html',
    controller:  DashboardTestController
  });
}]);