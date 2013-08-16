function DashboardTestController($scope, $route, $http, $timeout){
  $scope.isVisible = function(i){
    if(i.hide == true)
      return false;
    return true;
  }

  $scope.getSeriesNames = function(){
    rv = ['epoch'];

    if(angular.isDefined($scope.graph) &&
       angular.isDefined($scope.graph.series)){
      angular.forEach($scope.graph.series, function(v,k){
        rv.push(v.name)
      })
    }

    return rv.join(',');
  }


  $scope.reload = function(){
    $scope.show = null;
    $http.get('/api/dashboard/test').success(function(i){
      $scope.graph = i;
      $scope.show = 'graph';
    });
  };

  $scope.reload();
}