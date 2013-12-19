function QueryController($scope, $http, $interval, $route, $rootScope, $location, $routeParams){
  $scope.query = $routeParams.query;
  $scope.time_left = 0;
  $scope.pagenum = 1;
  $scope.sortField = 'name';
  $scope.sortReverse = false;
  $scope.reload_suspended = false;

  $scope.opt = {
    lastLoadTime: null
  };

  $scope.reload = function(force){
    if(($scope.reload_suspended == true && !(force === true)) || $scope.loading == true){
      return false;
    }

    $scope.loading = true;
    console.log('Reloading!')

  //run arbitrary query
    if($scope.query){
      var p = {
        query: 'tags/not:disabled/'+$scope.prepareQuery($scope.query, $routeParams.raw),
        only:  'name,status,maintenance_status,collected_at,alert_state,ip,site,model,rack,unit,slot,reserved,provisioning.class',
        sort:  ($scope.sortReverse && '-' || '')+($scope.sortField || 'name'),
        page:  ($scope.pagenum || 1)
      }

      if(angular.isDefined($scope.max_results) && $scope.max_results != null){
        if($scope.max_results < 0){
          p.max = 1000;
        }else{
          p.max = $scope.max_results;
        }
      }

      $http.get('/api/devices/find/', {
        params: p
      }).success(function(data,status,headers){
        if(data.length == 0){
          $scope.noresults = true;

        }else if(data.length == 1){
          $location.path('/node/'+data[0].id);

        }else{
          $scope.results = data;
        }

        if(headers('X-Onering-Results-Count')){
          $scope.pages = {
            results: parseInt(headers('X-Onering-Results-Count')),
            per:     parseInt(headers('X-Onering-Results-Page-Size')),
            current: parseInt(headers('X-Onering-Results-Page-Number')),
            total:   parseInt(headers('X-Onering-Results-Page-Count'))
          }
        }

        $scope.loading = false;
        $scope.opt.lastLoadTime = new Date();
        $scope.time_left = 0;
      });
    }
  }

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

  $scope.interval = 60000;
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

function NodeController($scope, $http, $location, $rootScope, $interval, $routeParams, $position){
  $scope.reload_suspended = false;

  $scope.opt = {
    ping:              null,
    diskTab:           'block',
    tabs:              {
      disk: []
    },
    netTab:            'interfaces',
    graphsFrom:        '-6hours',
    dns_sort:          ['type', 'name'],
    editProvisioning:  false,
    editPhysical:      false,
    provision: {
      formHelp: {},
      families: [{
        label: 'CentOS 5.9',
        value: 'centos-59'
      },{
        label: 'Ubuntu 12.04',
        value: 'ubuntu-1204'
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

  $scope.hasAddress = function(i){
    return (angular.isDefined(i['address']) && i['address'].length > 0);
  }

  $scope.reload = function(force){
    if($scope.reload_suspended == true && !(force === true)){
      return false;
    }

    if(!angular.isUndefined($routeParams.id)){
  //  device
      $http.get('/api/devices/'+$routeParams.id).success(function(data){
        $scope.node = data;
        $scope.opt.lastLoadTime = new Date();

        try{
          $scope.opt.newPxeProfile = $scope.node.properties.provisioning.boot.profile;
        }catch(e){ }

    //  load parent
        if($scope.node && $scope.node.parent_id){
          $http.get('/api/devices/'+$routeParams.id+'/parent?only=site').success(function(data){
            $scope.node.parent = data[0];
          });
        }

    //  populate disk tabs

    //  Block devices
        $scope.opt.tabs.disk = [];

        if(angular.isDefined($scope.node.properties.metrics.disk.block)){
          $scope.opt.tabs.disk.push({
            title:    'Devices',
            template: 'views/panes/node-pane-system-disk-block.html'
          });
        }

    //  Mounts
        if(angular.isDefined($scope.node.properties.metrics.disk.mounts)){
          $scope.opt.tabs.disk.push({
            title:    'Mounts',
            template: 'views/panes/node-pane-system-disk-mounts.html'
          });
        }

    //  LVM
        if(angular.isDefined($scope.node.properties.metrics.disk.lvm.group)){
          $scope.opt.tabs.disk.push({
            title:    'LVM',
            template: 'views/panes/node-pane-system-disk-lvm.html'
          });
        }

    //  ZFS
        if(angular.isDefined($scope.node.properties.metrics.zfs)){
          $scope.opt.tabs.disk.push({
            title:    'ZFS',
            template: 'views/panes/node-pane-system-disk-zfs.html'
          });
        }

    //  MDRAID
        if(angular.isDefined($scope.node.properties.metrics.disk.mdraid)){
          $scope.opt.tabs.disk.push({
            title:    'MDRAID',
            template: 'views/panes/node-pane-system-disk-mdraid.html'
          });
        }

    //  Virident
        if(angular.isDefined($scope.node.properties.metrics.virident)){
          $scope.opt.tabs.disk.push({
            title:    'Virident',
            template: 'views/panes/node-pane-system-disk-virident.html'
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

  $scope.$watch('opt.editProvisioning', function(value){
    $scope.reload_suspended = value;
  });

  $scope.ConsoleDialogController = function($scope){
    $scope.console = function(addr, port){
      return '<iframe src="http://'+addr+':'+(port || '2600')+'" frameborder="0" scrolling="no" style="width:100%; height:100%"></iframe>';
    }
  }

  $scope.$watch('interval', function(i){
    if(angular.isDefined(i)){
      if(angular.isDefined($scope.opt.interval_id)){
        $interval.cancel($scope.opt.interval_id);
      }

      $scope.opt.interval_id = $interval($scope.reload, i);
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

  $scope.interval = 60000;
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


function AssetDefaultsController($scope, $http, $timeout){
  $scope.opt = {
    tab_active: {}
  };

  $scope.sortField = 'name';
  $scope.sortReverse = false;
  $scope.node_defaults = {};

  $scope.add = function(group){
    var o = {
      name:    '',
      group:   group,
      match:   [],
      apply:   {},
      enabled: true
    };

    if(angular.isUndefined($scope.node_defaults[group || 'Ungrouped'])){
      $scope.node_defaults[group || 'Ungrouped'] = [];
    }

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
      $scope.reload()
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

    $http.get('/api/devices/schema/fields').success(function(data){
      $scope.autocomplete = data;
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
