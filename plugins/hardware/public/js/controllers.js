function HardwareSitesController($scope, $http){
  $scope.racks = {};

  $scope.reload = function(){
    $http.get('/api/devices/list/site').success(function(data){
      $scope.sites = data;
    });

    $http.get('/api/org/contacts/find/tags/datacenter').success(function(data){
      $scope.contacts = data;
    });
  }

  $scope.$watch('sites', function(){
    angular.forEach($scope.sites, function(i){
      $http.get('/api/hardware/rack/'+i).success(function(data){
        $scope.racks[i] = data;
      });
    });
  });

  $scope.reload();
}