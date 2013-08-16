  function DashboardController($scope, $http){
  $http.get('/api/dashboard/test').success(function(data){
    $scope.dashboard = data;
    $scope._display = 'visible';
  })
}

function GraphController($scope, $route, $http, $timeout){
  $scope.opt = {
    loading: false
  };

  $scope.palette = [
    '#6464FF',
    '#00C800',
    '#C80032',
    '#FFFF00',
    '#FF00FF',
    '#966432',
    '#FF6464'
  ]

  $scope.isVisible = function(i){
    if(i.hide == true)
      return false;
    return true;
  }

  $scope.reload = function(){
    $scope.opt.loading = true;

    if($scope.graph_id){
      if(!angular.isDefined($scope.graph_params)){
        $scope.graph_params = {
          from: '-2hours'
        };
      }

      $http({
        method: 'GET',
        url:    '/api/dashboard/graph/'+$scope.graph_id,
        params: $scope.graph_params
      }).success(function(graph){
        for(var i = 0; i < graph.data.schema.length; i++){
          graph.data.schema[i].color = $scope._color(graph, i);
        }

    //  inherit options from the pane
        if(angular.isDefined($scope.pane) && angular.isDefined($scope.pane.options)){
          for(var i in $scope.pane.options){
            if(!angular.isDefined(graph.options[i])){
              graph.options[i] = $scope.pane.options[i];
            }
          }
        }

        $scope.graph = graph;


        $scope.opt.loading = false;
      });
    }
  };

  $scope._color = function(graph, i){
    var schema = graph.data.schema[i];

    if(angular.isDefined(schema.color)){
      return schema.color;
    }else if(angular.isDefined(graph.options.colors)){
      for(var pattern in graph.options.colors){
        if(pattern == 'default'){
          continue;
        }

        if(RegExp(pattern,"i").test(schema.name)){
          return graph.options.colors[pattern];
        }
      }

      if(angular.isDefined(graph.options.colors['default'])){
        return graph.options.colors['default'];
      }else{
        return $scope.palette[i%$scope.palette.length];
      }
    }else if(angular.isDefined(graph.palette)){
      return graph.palette[i%graph.palette.length];
    }else{
      return $scope.palette[i%$scope.palette.length];
    }
  }

  $scope.$watch('graph_id', function(){
    $scope.reload();
  }, true);

  $scope.setFromTime = function(from){
    $scope.graph_params.from = from;
    $scope.reload();
  }
}