function WidgetChefStatus($scope, $http, $window){
  $scope.currentField = 'chef.last_run.state';

  $scope.chef_runs = [7,7,5,1,3,3,4,1,5,2,3,4,8,6,4,3,2,7,2,8];
  $scope.commits =   [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
  $scope.blockWidth = 80;

  $scope.reload = function(){
    var cr = $scope.chef_runs.slice(0);
    var cm = $scope.commits.slice(0);

    if(cr.length >= $scope.blockWidth)
      cr.pop();

    if(cm.length >= $scope.blockWidth)
      cm.pop();

    cr.unshift(parseInt(Math.random() * 1000));

    n = (Math.random() * 10)
    cm.unshift(n > 9 ? (Math.random() * 4) : 0);

    $scope.chef_runs = cr;
    $scope.commits = cm;

    $scope.$digest();

    $http.get('/api/devices/summary/by-'+$scope.currentField).success(function(data){
      $scope.chefStates = data;
    });
  }

  //$window.setInterval($scope.reload, 1000);
}