function provisioningSetNextAction(action, device_id, scope, http){
  if(typeof $scope != 'undefined' && !scope) scope = $scope;
  if(typeof $http != 'undefined' && !http) http = $http;
  if(scope && scope.device && !device_id) device_id = scope.device.id;

  if(device_id && action){
    action = action.split(':');
    target = null;

    if(action.length > 1){
      target = action.pop();
      action = action.shift();
    }

    if(target){
      http.get('/api/provision/'+device_id+'/boot/'+target).success(function(data){
        scope.bootTarget = target;

        http.get('/api/provision/'+device_id+'/set/action/'+action).success(function(d2){
          scope.nextAction = action;
        });
      });
    }else if(action == 'clear'){
      http.get('/api/provision/'+device_id+'/action?clear=true').success(function(data){
        scope.reload();
      });
    }else{
      scope.nextAction = action;
    }
  }
}


function ProvisioningController($scope, $http, $window, $timeout, Query, Device){
  $scope.defaults = {};

  $scope.reload = function(){
    if(!$scope.editing){
      $scope.selected = {};

      Query.query({
        query: 'status/allocatable|installing'
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

  $scope.deviceSelect = function(device, event){
    if(event.target.checked){
      $scope.selected[device.id] = device;
    }else{
      delete $scope.selected[device.id];
    }
  }

  $scope.deviceSelectAll = function(event){
    if(event.target.checked){
      for(var i in $scope.results){
        $scope.selected[$scope.results[i].id] = $scope.results[i];
      }
    }else{
      $scope.selected = {};
    }
  }

  $scope.deviceIsSelected = function(device){
    return ($scope.selected.hasOwnProperty(device.id));
  }

  $scope.setNextActions = function(action){
    //provisioningSetNextAction
    var devices = null;

    if($scope.selected.length == 0) devices = $scope.selected;

    for(var device_id in $scope.selected){
      provisioningSetNextAction(action, device_id, $scope, $http);
    }

    $scope.editing = false;
    $scope.reload();
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

        Asset.save({
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
  $scope.$watch('nextAction', function(){
    if($scope.device){
      $http.get('/api/provision/'+$scope.device.id+'/set/action/'+$scope.nextAction).success(function(data){
        $scope.reload();
      });
    }
  });

  $scope.setNextAction = function(action){
    provisioningSetNextAction(action, $scope.device.id, $scope, $http);
  }
}


function ProvisioningRequestController($scope, $http, $routeParams){
// teams
  $scope.teams = [
    'Core',
    'Data Management',
    'Homepage',
    'Operations',
    'Recommendations',
    'QA',
    'Visual Revenue',
  ];

  $scope.reload = function(){
  // roles
    $http.get('/api/devices/list/role').success(function(data){
      $scope.roles = data;
    })

  // my requests
    $http.get('/api/provision/request/find/user_id/'+$scope.user.id).success(function(data){
      $scope.requestsMine = data;
    });

    if($routeParams && $routeParams.id){
      $http.get('/api/provision/request/'+$routeParams.id).success(function(data){
        $scope.request = data;
      });
    }else{
      $scope.request = {
        quantity: {
          nydc1:  0,
          chidc1: 0,
          ladc1:  0
        }
      };
    }
  }

  $scope.reload();
}


function ProvisioningRequestListController($scope, $http, $routeParams){
  $scope.reload = function(){
    $http.get('/api/provision/request/find').success(function(data){
      $scope.requests = data;
    });
  }

  $scope.reload();
}