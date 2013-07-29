function HardwareSitesController($scope, $http){
  $scope.opt = {
    view:        'rear',
    loading:      true,
    current_unit: null
  };

  $scope.racks = {};

  $scope.reload = function(){
    $scope.opt.loading = true;

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
        $scope.opt.loading = false;
      });
    });
  });

  $scope.reload();
}