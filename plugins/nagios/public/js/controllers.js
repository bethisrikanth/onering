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


function WidgetNagios($scope, $http, $window, NagiosAlerts){
  $scope.sortField = 'last_alert_at';
  $scope.sortReverse = true;
  $scope.resultsLimit = 4;

  $scope.reload = function(){
    NagiosAlerts.query({}, function(data){
      $scope.results = data.sort(function(a,b){
        return ((a.last_alert_at < a.last_alert_at) ? -1 : ((a.last_alert_at > b.last_alert_at) ? 1 : 0));
      }).splice(0, $scope.resultsLimit);
    });
  };

  $scope.reload();
  $window.setInterval($scope.reload, 60000);
}