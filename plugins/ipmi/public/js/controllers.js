function IpmiRunController($scope, $http, $window){
  $scope.default_interval = 60000;
  $scope.node = null;
  $scope.states = {
    power: null
  }

  $scope.reload = function(silent){
    if($scope.node != null){
      $scope.reloadPower();
    }
  }

  $scope.reloadPower = function(){
    $http.get('/api/devices/'+$scope.node.id+'/ipmi/chassis.power.is_on').success(function(data){
      if(data.result != $scope.states.power){
        $scope.states.power = data.result;
        $scope.interval = $scope.default_interval;
      }
    });
  }

  $scope.$watch('parent', function(){
    $scope.node = $scope.parent.node;
    $scope.reload();
    $scope.interval = $scope.default_interval;
  })

  $scope.$watch('interval', function(i){
    if($scope._rl_power_id != null){
      $window.clearInterval($scope._rl_power_id)
    }

    if(i != $scope.default_interval){
      $scope.states.power = null;
    }

    $scope._rl_power_id = $window.setInterval(function(){
      $scope.reload();
    }, i);
  });
}