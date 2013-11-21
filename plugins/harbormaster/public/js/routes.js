angular.module('harbormasterRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/harbormaster/tasks', {
    templateUrl: 'views/harbormaster-tasks.html',
    controller:  HarbormasterTasksController
  })
}]);
