angular.module('provisioningRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/provisioning', {
    templateUrl: 'views/provisioning-list.html'
  });
}]);
