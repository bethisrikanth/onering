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

function SummaryController($scope, $http, $routeParams, $route){
  $scope.params = ($route.current.$route.params || {});
  $scope.field = $routeParams.field || $scope.params.field;
  $scope.orderProp = 'total';

  Summary.query({
    field: $scope.field
  }, function(data){
    $scope.summary = data;
  });
}

function OverviewController($scope, $http){
  var status_weights = {
    'online':      2000,
    'reserved':    1000,
    'allocatable': 100
  };

  $scope.infrastructure = {};

  $scope.reload = function(){
    $http.get('/api/devices/summary/by-site/status').success(function(data){

    });
  }

  $scope.reload();
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

function NodeController($scope, $http, $location, $routeParams, $window, $position, $dialog){
  $scope.opt = {
    ping:              null,
    diskTab:           'mounts',
    netTab:            'interfaces',
    graphsFrom:        '-6hours',
    dns_sort:          ['type', 'name'],
    editProvisioning:  true,
    provision: {
      formHelp: {},
      families: [{
        label: 'RedHat / CentOS',
        value: 'redhat'
      },{
        label: 'Debian / Ubuntu',
        value: 'ubuntu-test'
      }],
      diskStrategies: [{
        label: 'Mirrored',
        value: 'mirror'
      },{
        label: 'Single / HW RAID',
        value: 'single'
      },{
        label: 'Hadoop Datanode',
        value: 'hadoop'
      },{
        label: 'Xen Virtual Machine',
        value: 'single-vm-xen'
      },{
        label: 'KVM Virtual Machine',
        value: 'single-vm-kvm'
      },{
        label: 'Monolithic',
        value: 'monolithic'
      }]
    },
    newNote:           null,
    lastLoadTime:      null,
    graphTimes: [{
      label: '2h',
      value: '-2hours'
    },{
      label: '6h',
      value: '-6hours'
    },{
      label: '24h',
      value: '-1days'
    },{
      label: '3d',
      value: '-3days'
    },{
      label: '1w',
      value: '-1week'
    }]
  };

//  pane configuration
  $http.get('/api/devices/'+$routeParams.id+'/panes').success(function(data){
    $scope.panes = data;
  });

  $scope.hiddenPanes = function(pane){
    return !(pane.hidden === true);
  }

  $scope.isMasterInterface = function(i){
    if(i.master)
      return false;
    return true;
  }

  $scope.reload = function(){
    if(!angular.isUndefined($routeParams.id)){
  //  device
      $http.get('/api/devices/'+$routeParams.id).success(function(data){
        $scope.node = data;
        $scope.opt.lastLoadTime = new Date();

    //  load parent
        if($scope.node && $scope.node.parent_id){
          $http.get('/api/devices/'+$routeParams.id+'/parent?only=site').success(function(data){
            $scope.node.parent = data[0];
          });
        }
      });

  //  active alerts
      $http.get('/api/nagios/'+$routeParams.id+'?severity=ignore').success(function(data){
        $scope.nagios = data;
      });

  //  all tags
      $http.get('/api/devices/list/tags').success(function(data){
        $scope.tags = data;
      });

  //  boot profiles
      $http.get('/api/provision/'+$routeParams.id+'/boot/profile?severity=ignore').success(function(data){
        $scope.pxeboot = data;

        if(data[0]){
          $scope.opt.newPxeProfile = data[0].id;
        }
      });

  //  boot profile list
      $http.get('/api/provision/boot/profile/list?severity=ignore').success(function(data){
        $scope.pxeProfiles = data;
      });


  //  Give me a ping, Vasili.  One ping only please...
      // $http.get('/api/salt/devices/'+$routeParams.id+'/ping?severity=ignore').success(function(){
      //   $scope.opt.ping = true;
      // }).error(function(){
      //   $scope.opt.ping = false;
      // });
    }

    $scope.$broadcast('reload');
  }

  $scope.save = function(){
    $http.post('/api/devices/'+$routeParams.id+'?direct=true', $scope.node).success(function(){
      $scope.reload();
    })
  }

  $scope.$watch('opt.newNote', function(value){
    if(value !== null){
      $http.post('/api/devices/'+$routeParams.id+'/notes', value).success(function(){
        $scope.reload();
        $scope.opt.newNote = null;
      });

    }
  });

  $scope.tick = function(){
    $scope.opt.currentTime = new Date();
  }

  $scope.ConsoleDialogController = function($scope){
    $scope.console = function(addr, port){
      return '<iframe src="http://'+addr+':'+(port || '2600')+'" frameborder="0" scrolling="no" style="width:100%; height:100%"></iframe>';
    }
  }

  $window.setInterval($scope.tick, 1000);
  $window.setInterval($scope.reload, 60000);
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


function AssetDefaultsController($scope, $http){
  $scope.opt = {
    tab_active: {}
  };

  $scope.sortField = 'name';
  $scope.sortReverse = false;

  $scope.add = function(group){
    var o = {
      name:    '',
      group:   group,
      match:   [],
      apply:   {},
      enabled: true
    };

    $scope.node_defaults[group || 'Ungrouped'].push(o);
    $scope.edit(o);
  }

  $scope.remove = function(d, group){
    if(d.id){
      $http.delete('/api/devices/defaults/'+d.id).success(function(){
        $scope.reload();
      });

    }else{
      $scope.node_defaults[group || 'Ungrouped'].splice($scope.node_defaults[group || 'Ungrouped'].indexOf(d), 1);
    }
  }

  $scope.edit = function(d){
    $scope.current = d;
  }

  $scope.save = function(d){
    $http.post('/api/devices/defaults', d).success(function(){
      $scope.reload();
    });
  }

  $scope.setActiveTab = function(id){
    angular.forEach($scope.node_defaults, function(v,k){
      if(k == id){
        $scope.opt.tab_active[k] = true;
      }else{
        $scope.opt.tab_active[k] = false;
      }
    })
  }

  $scope.$watch('opt', function(i){
    console.log($scope.opt)
  });

  $scope.reload = function(){
    $http.get('/api/devices/defaults/groups').success(function(data){
      $scope.node_groups = data;
    });

    $http.get('/api/devices/defaults/list').success(function(data){
      $scope.node_defaults = data;

      if($scope.opt.tab_active.length == 0){
        $scope.opt.tab_active[data[0].group] = true;
      }

      $scope.current = null;
    });
  }

  $scope.addNewProperty = function(key){
    $scope.newApplyKey = (key || '(new)');
  }

  $scope.$watch('newApplyKey', function(){
    if($scope.newApplyKey && $scope.newApplyKey != '(new)'){
      if($scope.current && $scope.current.apply){
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
  $scope.sortField = 'name';
  $scope.sortReverse = false;

  $scope.reload = function(){
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
