var app = angular.module('app', []);

app.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
    when('/inf', {
      templateUrl: 'views/cards.html',
      controller:  PhysicalDeviceSummary
    }).
    when('/inf/summary/:field', {
      templateUrl: 'views/summary.html',
      controller:  PhysicalDeviceSummary
    }).
    when('/inf/:field', {
      templateUrl: 'views/devices.html',
      controller: PhysicalDevices
    }).
    when('/inf/:field/:query', {
      templateUrl: 'views/devices.html',
      controller: PhysicalDevices
    }).
    otherwise({
      templateUrl: 'views/index.html',
      controller:  DefaultController
    })
}]);

