angular.module('rickshaw', [])
.directive('graph', function() {
  return {
    restrict: 'A',
    scope: {
      type:   '=',
      data:   '@',
      url:    '@',
      from:   '@',
      to:     '@',
      width:  '@',
      height: '@',
      min:    '@',
      max:    '@',
      target: '@'
    },

    controller: function($scope, $element, $attrs, $http){
    },

    link: function($scope, $element, $attrs) {
      $scope.checkAndBuild = function(){
        if($scope.url_base && $scope.url_targets.length > 0){
          $scope.buildGraph($scope.url_base + '&' + $scope.url_targets.join('&'));
        }
      }

      $scope.buildGraph = function(url){
        delete $scope.graph;

        if(!angular.isUndefined($attrs.colors)){
          var colors = $attrs.colors.split(',');
        }

        $scope.palette = new Rickshaw.Color.Palette( { scheme: 'spectrum2001' } );

        $scope.graph = new Rickshaw.Graph.Ajax({
          element:  $element[0],
          renderer: ($scope.type || 'line'),
          width:    ($scope.width || $element.parent().width()),
          height:   ($scope.height || $element.parent().height()),
          min:      $scope.min,
          max:      $scope.max,
          dataURL:  url,
          onData:   function(d){
            var data = [];

            for(var i = 0; i < d.length; i++){
              var points = [];

              for(var j = 0; j < d[i].datapoints.length; j++){
                if(d[i].datapoints[j][0] == null)
                  continue;

                points.push({
                  x: d[i].datapoints[j][1],
                  y: d[i].datapoints[j][0]
                });
              }

              data.push({
                data:  points,
                name:  d[i].target,
                color: (colors[i] || $scope.palette.color())
              })
            }

            return data;
          }
        })

        $element.empty();
      };

      $scope.$watch('target', function(value){
        if(!angular.isUndefined(value)){
          var url = [];
          value = value.split('|');

          for(var i = 0; i < value.length; i++){
            url.push('target='+value[i]);
          }

          $scope.url_targets = url;

          $scope.checkAndBuild();
        }
      });

      $scope.$watch('url', function(value){
        if(!angular.isUndefined(value)){
          $scope.url_base = $.jurlp(value).query({
            format: 'json'
          }).href;

          $scope.checkAndBuild();
        }
      });
    }
  }
})