function HardwareSitesController($scope, $http){
  $scope.opt = {
    view:        'rear',
    loading:      true,
    current_unit: null,
    sites:        {}
  };

  $scope.racks = {};

  $scope.reload = function(){
    $scope.opt.loading = true;

    $http.get('/api/hardware/sites').success(function(data){
      $scope.sites = data;

      angular.forEach(data, function(i){
        $scope.opt.sites[i.id] = {
          contact_pane: 'facility'
        }
      });
    });

    $http.get('/api/org/contacts/find/tags/datacenter').success(function(data){
      $scope.contacts = data;
    });
  }

  $scope.$watch('sites', function(){
    angular.forEach($scope.sites, function(i){
      $http.get('/api/hardware/rack/'+i.id).success(function(data){
        $scope.racks[i.id] = data;
        $scope.opt.loading = false;
      });
    });
  });

  $scope.reload();
}