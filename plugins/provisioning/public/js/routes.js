angular.module('provisioningRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/provisioning', {
    templateUrl: 'views/provisioning-list.html'
  }).
  when('/provisioning/request', {
    templateUrl: 'views/provisioning-request.html',
    controller:  'ProvisioningRequestController'
  }).
  when('/provisioning/request/:id', {
    templateUrl: 'views/provisioning-request.html',
    controller:  'ProvisioningRequestController'
  });
}]);
