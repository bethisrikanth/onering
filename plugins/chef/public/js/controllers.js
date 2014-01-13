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


function ChefConsoleController($scope, $http, $rootScope, $interval, $location){
  $scope.pagenum = 1;
  $scope.sortField = 'name';
  $scope.sortReverse = false;
  $scope.reload_suspended = false;
  $scope.selected_state = ($location.search().state || 'succeeded');

  $scope.reload = function(force){
    if(($scope.reload_suspended == true && !(force === true)) || $scope.loading == true){
      return false;
    }

    $scope.loading = true;

    $http.get('/api/devices/summary/by-chef.last_run.state').success(function(data){
      $scope.states = data;
    })

    var p = {
      q:     'chef.last_run.state/'+$scope.selected_state,
      only:  'name,status,maintenance_status,collected_at,alert_state,ip,site,reserved,chef',
      sort:  ($scope.sortReverse && '-' || '')+($scope.sortField || 'name'),
      page:  ($scope.pagenum || 1)
    };

    if(angular.isDefined($scope.max_results) && $scope.max_results != null){
      if($scope.max_results < 0){
        p.max = 1000;
      }else{
        p.max = $scope.max_results;
      }
    }

    $http.get('/api/devices/find', {
      params: p
    }).success(function(data,status,headers){
      if(headers('X-Onering-Results-Count')){
        $scope.pages = {
          results: parseInt(headers('X-Onering-Results-Count')),
          per:     parseInt(headers('X-Onering-Results-Page-Size')),
          current: parseInt(headers('X-Onering-Results-Page-Number')),
          total:   parseInt(headers('X-Onering-Results-Page-Count'))
        }
      }


      $scope.results = data;

      $scope.loading = false;
    })
  }


  $scope.$watch('selected_state', function(){
    $scope.reload();
  });

  $scope.sort = function(field, rev){
    if(angular.isUndefined(rev)){
      if(field != $scope.sortField){
        $scope.sortReverse = false;
      }else{
        $scope.sortReverse = !$scope.sortReverse;
      }
    }else{
      $scope.sortReverse = rev;
    }

    $scope.sortField = field;
    $scope.reload();
  }

  $scope.$watch('pagenum', function(){
    if($scope.pages){
      if($scope.pagenum > $scope.pages.total){
        $scope.pagenum = $scope.pages.total;
      }
    }else if($scope.pagenum < 1){
      $scope.pagenum = 1;
    }

    $scope.reload();
  });

  $scope.$watch('max_results', function(){
    $scope.reload();
  });

  $scope.$watch('filter', function(i){
    if(angular.isDefined(i)){
      $location.path('/search/'+$scope.query+' '+i);
    }
  });

  $scope.$watch('interval', function(){
    if(angular.isDefined($scope.interval)){
      if(angular.isDefined($scope.interval_id)){
        $interval.cancel($scope.interval_id);
      }

      console.log('Setting interval to', $scope.interval)
      $scope.interval_id = $interval($scope.reload, $scope.interval);
      $scope.reload();
    }
  });

//cleanup timers
  $rootScope.$on('$locationChangeStart',function(evt,next,current){
    if(next != current && angular.isDefined($scope.interval_id)){
      console.log("Clearing intervals for", current)
      $interval.cancel($scope.interval_id);
    }
  });

  $scope.interval = ($location.search().interval || 60000);
  $scope.reload();
}