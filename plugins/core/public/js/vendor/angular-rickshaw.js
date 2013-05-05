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
      height: '@'
    },

    controller: function($scope, $element, $attrs, $http){

    },

    link: function($scope, $element, $attrs) {
      $scope.$watch('from', function(value){
        $scope.url = $.jurlp($scope.url).query({
          from: value
        }).href;
      });

      $scope.$watch('url', function(value){
        delete $scope.graph;

        if($attrs.colors)
          var colors = $attrs.colors.split(',');

        $scope.graph = new Rickshaw.Graph.Ajax({
          element:  $element[0],
          renderer: ($scope.type || 'line'),
          width:    ($scope.width || $element.parent().width()),
          height:   ($scope.height || $element.parent().height()),
          dataURL:  $.jurlp(value).query({
            format: 'json'
          }).href,
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
                color: (colors[i % colors.length] || 'grey')
              })
            }

            return data;
          }
        })

        $element.empty();
      });
    }
  }
})