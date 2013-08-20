angular.module('dashRoutes', ['ng']).
config(['$routeProvider', function($routeProvider){
  $routeProvider.
  when('/dash', {
    templateUrl: 'views/dash-panel.html',
    controller:  DashboardController
  });
}]);