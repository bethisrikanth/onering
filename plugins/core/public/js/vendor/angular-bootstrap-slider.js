angular.module('slider', ['ui.bootstrap'])
.directive('slider', function(){
  return {
    restrict:   'E',
    template:   '<input ng-transclude type="text"></input>',
    require:    '?ngModel',
    replace:    true,
    transclude: true,
    scope:      {},

    controller: function($scope){
      $scope.setValue = function(i){
        if(angular.isDefined($scope.values)){
          $scope.value = ($scope.values[i] || $scope.min);
        }else{
          $scope.value = i;
        }
      }
    },

    link: function($scope, $element, $attrs, $ngModel){
      $scope.$watch('value', function(i){
        $ngModel.$setViewValue(i);
      })

      if(angular.isDefined($attrs.values)){
        $scope.values = $scope.$eval($attrs.values);

    //  split string
        if(angular.isString($scope.values)){
          $scope.values = $scope.values.split(',');
        }

    //  intify all values
        $scope.values = $scope.values.map(function(v){
          return parseInt(v);
        })

        if(angular.isDefined($attrs.min)){
          $scope.min = $scope.values.indexOf(parseInt($attrs.min))
        }else{
          $scope.min = 0;
        }

        if(angular.isDefined($attrs.max)){
          $scope.max = $scope.values.indexOf(parseInt($attrs.max))
        }else{
          $scope.max = ($scope.values.length - 1);
        }
      }else{
        $scope.min = parseInt($attrs.min || 0);
        $scope.max = parseInt($attrs.max || 10);
        $scope.setValue($ngModel.$viewValue);
      }

      $element.slider({
        min:         $scope.min,
        max:         $scope.max,
        step:        parseFloat($attrs.step || 1),
        orientation: $attrs.orientation,
        formater:    function(i){
          if(angular.isDefined($scope.values)){
            return $scope.values[i];
          }else{
            return i;
          }
        }
      }).on('slide', function(ev){
        $scope.setValue(ev.value);
        $scope.$apply();
      });

      $ngModel.$render = function(){
        if(angular.isDefined($scope.values)){
          $scope.setValue($scope.values.indexOf($ngModel.$viewValue));
          $element.slider('setValue', $scope.values.indexOf($ngModel.$viewValue));
        }else{
          $scope.setValue($ngModel.$viewValue);
          $element.slider('setValue', $ngModel.$viewValue);
        }
      }
    }
  };
})