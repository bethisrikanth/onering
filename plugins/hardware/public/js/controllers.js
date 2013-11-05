function HardwareSitesController($scope, $http){
  $scope.site = null;
  $scope.rack = null;
  $scope.opt = {
    view:        'rear',
    loading:      true,
    current_unit: null,
    sites:        {}
  };


  $scope.reload = function(){
    $scope.opt.loading = true;

    $http.get('/api/hardware/sites').success(function(data){
      $scope.sites = data;

      angular.forEach(data, function(i){
        $scope.opt.sites[i.id] = {
          contact_pane: 'facility'
        }
      });

      if($scope.site != null){
        $scope.loadSite($scope.site);
      }
    });

    $http.get('/api/org/contacts/find/tags/datacenter').success(function(data){
      $scope.contacts = data;
    });
  }

  $scope.loadSite = function(site){
    console.log("Loading Site", site)

    $scope.site = site;
    $scope.rack = $scope.loadRack(site, site.racks[0]);
    $scope.opt.loading = false;
  };

  $scope.loadRack = function(site, rack){
    console.log("Loading Rack", site.id, rack);

    $http.get('/api/hardware/rack/'+site.id+'/'+rack).success(function(data){
      $scope.rack = data;
    });
  }

  $scope.hideEmptyUnits = function(unit){
    if($scope.opt.hideEmpty === true){
      if(angular.isUndefined(unit.nodes) || unit.nodes.length == 0){
        return false;
      }
    }

    return true;
  }

  $scope.reload();
}