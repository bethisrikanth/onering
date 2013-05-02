angular.module('rest', [])
.directive('rest', function() {
  return {
    scope: {
      rest:         '@',
      restMethod:   '@',
      restSeverity: '@',
      restSuccess:  '&',
      restError:    '&',
      restData:     '&'
    },

    controller: function($scope, $element, $attrs, $http){
      $scope.callHttp = function(method, url, data){
        if(url){
          $http({
            method: (method ? method.toUpperCase() : 'GET'),
            url:    url,
            data:   JSON.stringify(data()),
            params: {
              severity: ($scope.restSeverity || 'ignore')
            }
          }).success(function(data, status, headers, config){
            if($scope.restSuccess){
              $scope.restSuccess({
                response: {
                  data:    data,
                  status:  status,
                  headers: headers,
                  config:  config
                }
              });
            }
          }).error(function(data, status, headers, config){
            if($scope.restError){
              $scope.restError({
                response: {
                  data:    data,
                  status:  status,
                  headers: headers,
                  config:  config
                }
              });
            }
          });
        }
      }
    },

    link: function($scope, $element, $attrs) {
      $element.bind('click', function(){
        $scope.callHttp($scope.restMethod, $scope.rest, $scope.restData);
      })
    }
  }
})