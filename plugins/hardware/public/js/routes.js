angular.module('hardwareRoutes', ['ng']).
config(['$routeProvider', function($routeProvider){
  $routeProvider.
  when('/hardware/sites', {
    templateUrl: 'views/hardware-sites.html',
    controller:  HardwareSitesController
  })
}]);