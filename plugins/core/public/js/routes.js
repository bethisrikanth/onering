angular.module('coreRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/error', {
    templateUrl: 'views/error.html',
    controller:  ErrorController
  }).
  otherwise({
    templateUrl: 'views/index.html'
  });
}]);
