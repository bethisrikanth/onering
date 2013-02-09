angular.module('coreRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/users/manage', {
    templateUrl: 'views/user-manager.html',
    controller:  UserManagerController
  }).
  when('/logout', {
    templateUrl: 'views/user-logout.html',
    controller:  LogoutController
  }).
  when('/error', {
    templateUrl: 'views/error.html',
    controller:  ErrorController
  }).
  otherwise({
    templateUrl: 'views/index.html'
  });
}]);
