function ProvisioningController($scope, $http, $timeout, Query){
  $scope.reload = function(){
    Query.query({
      query: 'status/provisioning'
    }, function(data){
      if(data.length == 0){
        $scope.noresults = true;
      }else{
        $scope.results = data;
      }
    });
  }

  $scope.edit = function(){
    $scope.editing = true;
  }

  $scope.reload();
}