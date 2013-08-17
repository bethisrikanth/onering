angular.module('dashRoutes', ['ng']).
config(['$routeProvider', function($routeProvider){
  $routeProvider.
  when('/', {
    templateUrl: 'views/dash-panel.html',
    controller:  DashboardController
  });
}]);