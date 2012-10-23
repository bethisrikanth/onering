function DefaultController($scope){

}

function PhysicalDevices($scope, $http, $routeParams){
  $scope.field = $routeParams.field;
  $scope.query = $routeParams.query || '';

  $http({
    method: 'GET',
    url:    'http://192.168.82.222:9393/devices/find/'+$scope.field+'/'+$scope.query,

  }).success(function(data){
    $scope.devices = data;
  });
}

function PhysicalDeviceSummary($scope, $http, $routeParams){
  $scope.field = $routeParams.field || 'site';

  $http({
    method: 'GET',
    url:    'http://192.168.82.222:9393/devices/summary/by-'+$scope.field,

  }).success(function(data){
    $scope.summary = data;
  });

  $scope.orderProp = 'total';
}