function ProvisioningController($scope, $http, $window, $timeout, Query, Device){
  $scope.defaults = {};

  $scope.reload = function(){
    if(!$scope.editing){
      Query.query({
        query: 'status/provisioning:installing'
      }, function(data){
        if(data.length == 0){
          $scope.noresults = true;
        }else{
          $scope.results = data;
        }
      });

      $scope.load_time = new Date();
    }
  }

  $scope.$watch('saved', function(){
    if($scope.saved){
      $timeout(function(){
        $scope.saved = null;
      }, 3000);
    }
  });


  $scope.reapply = function(){
    try { $scope.$apply(); }catch(e){ }
  }

  $scope.edit = function(){
    $scope.editing = true;
  }

  $scope.save = function(){
    $.each($scope.results, function(idx, i){
      if(i.properties){
        if(!i.properties.provisioning){
          i.properties.provisioning = {};
        }

        if(!i.properties.provisioning.network){
          i.properties.provisioning.network = {};
        }

        if(!i.properties.provisioning.network.dns || i.properties.provisioning.network.dns.length == 0)
          i.properties.provisioning.network.dns = $scope.defaults.dns;

        if(!i.properties.provisioning.network.netmask || i.properties.provisioning.network.netmask.length == 0)
          i.properties.provisioning.network.netmask = $scope.defaults.netmask;

        if(!i.properties.provisioning.network.gateway || i.properties.provisioning.network.gateway.length == 0)
          i.properties.provisioning.network.gateway = $scope.defaults.gateway;

        if(i.properties.site){
          i.properties.site = i.properties.site.toLowerCase();
        }

        Device.save({
          id: i.id,
          properties: i.properties
        }, function(){
          $scope.saved = 'Changes saved';
          $scope.editing = false;
        });
      }
    });
  }

  $window.setInterval($scope.reload, 15000);
  $window.setInterval($scope.reapply, 1000);
  $scope.reload();
  $scope.editing = true;
}

function ProvisioningNodeController($scope, $http){
  $scope.setNextAction = function(action){
    if($scope.device && action){
      if(action == 'reboot-install'){
        $http.get('/api/provision/'+$scope.device.id+'/boot/install').success(function(data){
          action = 'reboot';
        });
      }

      $http.get('/api/provision/'+$scope.device.id+'/set/action/'+action).success(function(data){
        $scope.reload();
      });
    }
  }
}