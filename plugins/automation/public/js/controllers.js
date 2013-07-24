function AutomationController($scope, $http, $window){
  $scope.jobs = {
    status: {},
    data:   []
  };

  $scope.reload = function(){
    $http.get('/api/automation/requests/status/unfinished').success(function(data){
      $scope.jobs.data = data;
    });

    $http.get('/api/automation/requests/summary/status').success(function(data){
      $scope.jobs.status = {};

      angular.forEach(data, function(v,k){
        $scope.jobs.status[v.id] = v.count;
      });
    });
  }

  $scope.reload();
  $window.setInterval($scope.reload, 5000);
}