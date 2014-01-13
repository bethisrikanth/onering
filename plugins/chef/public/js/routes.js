angular.module('chefRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/chef/console', {
    templateUrl: 'views/chef-console.html',
    controller:  ChefConsoleController
  });
}]);
