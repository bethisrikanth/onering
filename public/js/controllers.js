function DefaultController($scope){

}

function QueryController($scope, $http, $route, $routeParams){
  $scope.field = $routeParams.field;
  $scope.query = $routeParams.query || '';
  $scope.params = $route.current.$route.params;

  console.log('t', $routeParams)

  $http.get('/devices/find/' + $scope.field + '/' + $scope.query
  ).success(function(data){
    $scope.devices = data;
  });
}

function DeviceSummaryController($scope, $http, $routeParams){
  $scope.field = $routeParams.field || 'site';

  $http.get('/devices/summary/by-' + $scope.field
  ).success(function(data){
    $scope.summary = data;
  });

  $scope.orderProp = 'total';
}

function SiteController($scope, $http, $routeParams){
  $scope.site = $routeParams.site;

  $http.get('/devices/find/site/' + $scope.site
  ).success(function(data){
    $scope.devices = data;
  });
}

function RackController($scope, $http, $routeParams){
  $scope.site = $routeParams.site;
  $scope.rack = $routeParams.rack;

  $http.get('/devices/find/site/' + $scope.site+'/model/' + $scope.rack
  ).success(function(data){
    $scope.devices = data;
  });
}

function NodeController($scope, $http, $routeParams){
  $scope.id = $routeParams.id;

  $http.get('/devices/' + $scope.id
  ).success(function(data){
    $scope.device = data;
  });
}