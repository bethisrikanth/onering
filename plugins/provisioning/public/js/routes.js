angular.module('provisioningRoutes', ['ng']).
config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/provisioning/request/list', {
    templateUrl: 'views/provisioning-request-list.html',
    controller:  'ProvisioningRequestListController'
  }).
  when('/provisioning/request/:id', {
    templateUrl: 'views/provisioning-request.html',
    controller:  'ProvisioningRequestController'
  }).
  when('/provisioning/request', {
    templateUrl: 'views/provisioning-request.html',
    controller:  'ProvisioningRequestController'
  }).
  when('/provisioning', {
    templateUrl: 'views/provisioning-list.html'
  });
}]);
