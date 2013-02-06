angular.module('coreRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/users/manage', {
    templateUrl: 'views/user-manager.html',
    controller:  UserManagerController
  }).
  otherwise({
    templateUrl: 'views/index.html',
    controller:  DefaultController
  });
}]);
