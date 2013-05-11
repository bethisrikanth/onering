angular.module('rest', [])
.directive('restShow', function(){
  return {
    restrict: 'EA',
    scope: {
      restShow:     '@',
      restMethod:   '@',
      restCode:     '@',
      restInterval: '@',
      restSeverity: '@'
    },

    controller: function($scope, $element, $attrs, $http, $window){
      var testResponse = function(status, fallback){
        if(!$scope.restCode){
          return fallback;
        }else{
          var code = $scope.restCode;

          if(!angular.isArray(code)){
            code = [code];
          }

          return (code.indexOf(s) > -1);
        }
      }

      $scope.checkHttpStatus = function(method, url){
        console.log('CSTAT', method, url)

        if(url){
          $http({
            method: (method || 'head'),
            url:    url,
            params: {
              severity: ($scope.restSeverity || 'ignore')
            }
          })
          .success(function(d,s,h,c){
            return testResponse(s, true);
          })
          .error(function(d,s,h,c){
            return testResponse(s, false);
          })
        }
      }
    },

    link: function($scope, $element, $attrs){
      $scope.recheck = function(){
        if($scope.checkHttpStatus($scope.restMethod, $scope.restShow) === true){
          $element.show();
        }else{
          $element.hide();
        }
      }

      if($scope.restInterval){
        $window.setInterval($scope.recheck, +$scope.restInterval);
      }

      $scope.$watch('restShow', function(){
        if($scope.restShow){
          $scope.recheck();
        }
      })
    }
  };
})
.directive('rest', function() {
  return {
    restrict: 'EA',

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