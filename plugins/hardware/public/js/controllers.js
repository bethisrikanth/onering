function HardwareSitesController($scope, $http){
  $scope.racks = {};

  $http.get('/api/devices/list/site').success(function(data){
    $scope.sites = data;
  });

  $scope.$watch('sites', function(){
    angular.forEach($scope.sites, function(i){
      $http.get('/api/hardware/list/racks/'+i).success(function(data){
        $scope.racks[i] = data;
      });
    });
  });
}