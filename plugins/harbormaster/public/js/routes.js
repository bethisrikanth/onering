angular.module('harbormasterRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/harbormaster/tasks', {
    templateUrl: 'views/harbormaster-tasks.html',
    controller:  HarbormasterTasksController
  }).
  when('/harbormaster/task/:id', {
    templateUrl: 'views/harbormaster-task-editor.html',
    controller:  HarbormasterTaskEditorController
  })
}]);
