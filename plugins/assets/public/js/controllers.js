function QueryController($scope, $http, $window, $route, $location, $routeParams, Query){
  $scope.query = $routeParams.query;
  $scope.time_left = 0;

  $scope.reload = function(){
    $scope.loading = true;

  //run arbitrary query
    if($scope.query){
      Query.query({
        query: $scope.prepareQuery($scope.query, $routeParams.raw),
        only:  'alert_state,ip,site,model,rack,unit,slot'
      }, function(data){
        if(data.length == 0){
          $scope.noresults = true;

        }else if(data.length == 1){
          $location.path('/node/'+data[0].id);

        }else{
          $scope.results = data;

        }

        $scope.loading = false;
        $scope.time_left = 0;
      });
    }
  }

  $scope.setAutoReload = function(interval){
    console.log(interval)
    if(interval){
      if($scope.autoreload_id) $scope.clearAutoReload();
      $scope.autoreload_id = $window.setInterval($scope.reload, interval);
      $scope.time_left = interval;
      $scope.reload();
    }
  }

  $scope.clearAutoReload = function(){
    if($scope.autoreload_id){
      $window.clearInterval($scope.autoreload_id);
      $scope.autoreload_id = null;
      $scope.time_left = 0;
    }
  }

  $scope.updateTime = function(){
    $scope.time_left -= 1;
  }

  $window.setInterval($scope.updateTime, 1000);
  $scope.reload();
}

function SummaryController($scope, $http, $routeParams, $route, Summary){
  $scope.params = ($route.current.$route.params || {});
  $scope.field = $routeParams.field || $scope.params.field;
  $scope.orderProp = 'total';

  Summary.query({
    field: $scope.field
  }, function(data){
    $scope.summary = data;
  });
}

function OverviewController($scope, Summary){
  $scope.graphs = {
    'default': {

    }
  };

  Summary.query({
    field: 'status'
  }, function(data){
    for(var s in data){
      $scope.graphs.overview = $scope.summary_to_graphite(data);
    }

    console.log($scope.graphs);
  });
}

function DeviceListController($scope, $http, $timeout, Device, DeviceNote){
  $scope.sortField = 'name';

  $scope.$watch('saved', function(){
    if($scope.saved){
      $timeout(function(){
        $scope.saved = null;
      }, 3000);
    }
  });

  $scope.edit = function(){
    $scope.editing = true;
  }

  $scope.save = function(){
    $.each($scope.results, function(idx, i){
      if(i.properties)
        if(i.properties.rack)
          if(i.properties.rack.length > 0)
            Device.save({
              id: i.id,
              properties: {
                rack: i.properties.rack,
                unit: i.properties.unit
              }
            }, function(){
              $scope.saved = 'Changes saved';
              $scope.editing = false;
            });
    });
  }
}

function SiteController($scope, $http, $routeParams, Query, Site, SiteContact){
  $scope.site = $routeParams.site;
  $scope.results = null;

//site summary
  Site.query({
    site: $scope.site
  }, function(data){
    $scope.summary = data[0];

    if($scope.summary){
      $scope.racks = $scope.summary.children;
    }
  });

//racked devices
  SiteContact.query({
    site: $scope.site
  }, function(data){
    $scope.contact = data[0];
  });

//all devices
  Query.query({
    query: 'site/'+$scope.site,
    only:  'alert_state,ip,site,model,rack,unit,slot'
  }, function(data){
    $scope.results = data;
  });

  $scope.addRack = function(){
    $scope.racks.push({
      'id': 'Untitled'
    })
  }

  $scope.saveRack = function(rack, old){
    delete rack.editing;
    var devices = [];

    $http.post('/api/devices/find/site/'+$scope.site+'/rack/'+rack.old+'/?set=rack:'+rack.id);
  };
}

function RackController($scope, $http, $routeParams, Rack){
  $scope.site = $routeParams.site;
  $scope.rack = $routeParams.rack;

  Rack.query({
    site: $scope.site,
    rack: $scope.rack
  }, function(data){
    $scope.results = data;
  });
}

function NodeController($scope, $http, $location, $routeParams, $window, Device, DeviceNote, NagiosHost){
  $scope.diskTab = 'mounts';
  $scope.opt = {};

  $scope.reload = function(){
    Device.get({
      id: $routeParams.id
    }, function(data){
      $scope.node = data;
    });

    $http.get('/api/devices/'+$routeParams.id+'/panes').success(function(data){
      $scope.panes = data;
    });
  }

  $scope.reload();
}


function RackerController($scope, $window, Query){
  $scope.recheck = function(){
    if(!$scope.editing){
      Query.query({
        query: 'identify/on'
      }, function(data){
        $scope.device = data[0];
      });
    }
  };

  $scope.recheck();
  $window.setInterval($scope.recheck, 2000);
}


function AssetManagerController($scope){

}


function AssetDefaultsController($scope, $http, AssetDefault){
  $scope.sortField = 'id';
  $scope.sortReverse = false;

  $scope.add = function(){
    var o = {
      name:  '',
      match: [],
      apply: {}
    };

    $scope.defaults.push(o);
    $scope.edit(o);
  }

  $scope.remove = function(d){
    if(d.id){
      $http.delete('/api/devices/defaults/'+d.id).success(function(){
        $scope.reload();
      });

    }else{
      $scope.defaults.splice($scope.defaults.indexOf(d), 1);
    }
  }

  $scope.edit = function(d){
    $scope.current = d;
  }

  $scope.save = function(d){
    console.log(d);
    $http.post('/api/devices/defaults', d).success(function(){
      $scope.reload();
    });
  }

  $scope.reload = function(){
    AssetDefault.query(function(data){
      $scope.defaults = data;
      $scope.current = null;
    });
  }

  $scope.addNewProperty = function(key){
    $scope.newApplyKey = (key || '(new)');
  }

  $scope.$watch('newApplyKey', function(){
    if($scope.newApplyKey && $scope.newApplyKey != '(new)'){
      if($scope.current && $scope.current.apply){
        console.log($scope.newApplyKey)
        $scope.current.apply[$scope.newApplyKey] = null;
        $scope.newApplyKey = null;
      }
    }
  })

  $scope.reload();
}

function TreeViewController($scope){
  $scope.delete = function(node) {
    node = {};
  };

  $scope.add = function(node) {
    node = {
      '(name)': null
    };
  };

  $scope.isObject = function(node){
    return $.isPlainObject(node);
  }
}

function NodeCompareController($scope, $routeParams, Query){
  $scope.query = ($routeParams.query ? $routeParams.query : null);
  $scope.fields = ($routeParams.fields ? $routeParams.fields.split('|') : []);

  $scope.reload = function(){
    console.log('lol');

    if($scope.fields.length > 0 && $scope.query){
      Query.query({
        query: $scope.prepareQuery($scope.query, $routeParams.raw),
        only:  $scope.fields.join(',')
      }, function(data){
        $scope.results = data;
      });
    }
  }

  $scope.removeField = function(name){
    $scope.fields.splice($scope.fields.indexOf(name),1);
  }

  $scope.addField = function(name){
    $scope.fields = $scope.fields.push(name);
  }

  $scope.$watch('query', $scope.reload);
  $scope.$watch('fields', $scope.reload);
}