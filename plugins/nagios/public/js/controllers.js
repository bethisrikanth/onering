function NagiosAlertListController($scope, $http, $route, $window, $routeParams, NagiosAlerts){
  $scope.query = $routeParams.query;
  $scope.params = $route.current.$route.params;
  $scope.sortField = 'last_alert_at'
  $scope.sortReverse = true;
  $scope.load_age = 0;

  $scope.reload = function(){
    NagiosAlerts.query({}, function(data){
      $scope.results = data;
      $scope.load_age = 0;
    });
  };

  $scope.updateAlertAge = function(){
    $scope.load_age += 1;
    try { $scope.$apply(); }catch(e){ }
  };

  $window.setInterval($scope.updateAlertAge, 1000);
  $window.setInterval($scope.reload, 60000);
  $scope.reload();
}