angular.module('coreRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  otherwise({
    templateUrl: 'views/index.html',
    controller:  DefaultController
  });
}]);
