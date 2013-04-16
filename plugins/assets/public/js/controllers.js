function QueryController($scope, $http, $window, $route, $location, $routeParams, Query){
  $scope.query = $routeParams.query;
  $scope.params = $route.current.$route.params;
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
  $scope.id = $routeParams.id;
  $scope.note = null;
  $scope.hidAsAColor = false;
  $scope.newtags = [];
  $scope.alert_init_limit = 3;
  $scope.alert_show_limit = $scope.alert_init_limit;
  $scope.alert_load_age = 0;
  $scope.current_net_tab = 'system';
  $scope.deleteConfirmId = null;
  $scope.redeployConfirmId = null;

  $scope.reload = function(id){
    var id = id || $scope.id;

    Device.get({
      id: id
    }, function(data){
      $scope.device = data;
    });

    $scope.reloadAlerts(id);
    $scope.load_time = new Date();
  };

  $scope.reloadAlerts = function(id){
    $scope.alert_load_age = 0;

    NagiosHost.get({
      id: (id || $scope.id)
    }, function(data){
      $scope.nagios_alerts = [];

      if(data.alerts){
        $scope.nagios_alerts = data.alerts;
      }
    });
  }

  $scope.updateAlertAge = function(){
    $scope.alert_load_age += 1;
    try { $scope.$apply(); }catch(e){ }
  };

  $scope.saveNote = function(note_id){
    if($scope.note){
      if($scope.device && $scope.device.properties){
        if(!$scope.device.properties.notes)
          $scope.device.properties.notes = [];

        DeviceNote.save({
          id: $scope.device.id
        }, $scope.note, function(){
          if(note_id)
            $scope.deleteNote(note_id);

          $scope.old_note_id = null;
          $scope.note = null;
          $scope.reload($scope.device.id);
        });
      }
    }
  };

  $scope.editNote = function(note_id){
    $scope.old_note_id = note_id;
    $scope.note = $scope.device.properties.notes[note_id].body;
  };

  $scope.deleteNote = function(note_id){
    DeviceNote.delete({
      id: $scope.device.id,
      note_id: note_id
    }, function(){
      $scope.reload($scope.device.id);
    })
  };

  $scope.setStatus = function(status){
    if($scope.device && status){
      $http.get('/api/devices/'+$scope.device.id+'/status/'+status).success(function(data){
        $scope.reload();
      });
    }
  };

  $scope.setProperty = function(property, value){
    console.log('set', property, value)
    if($scope.device && property && value !== undefined){
      $http.get('/api/devices/'+$scope.device.id+'/set/'+property+'/'+value).success(function(data){
        $scope.reload();
      });
    }
  };

  $scope.setMaintStatus = function(status){
    if($scope.device && status){
      $http.get('/api/devices/'+$scope.device.id+'/maintenance/'+status).success(function(data){
        $scope.reload();
      });
    }
  };

  $scope.tag = function(value){
    if($scope.device && typeof(value) == 'string' && $.trim(value).length > 0){
      $http.get('/api/devices/'+$scope.device.id+'/tag/'+value).success(function(){
        $scope.reload();
      });
    }
  };

  $scope.untag = function(value){
    if($scope.device && value && typeof(value) == 'string'){
      $http.get('/api/devices/'+$scope.device.id+'/untag/'+value).success(function(data){
        $scope.reload();
      });
    }
  };

  $scope.saveTags = function(){
    for(var i in $scope.newtags){
      $scope.tag($scope.newtags[i]);
    }

    $scope.newtags = [];
  };

  $scope.deleteNode = function(){
    if($scope.device){
      if($scope.deleteConfirmId){
        if($scope.device.id == $scope.deleteConfirmId){
          $http.delete('/api/devices/'+$scope.device.id).success(function(){
            $location.path('/inf');
          });
        }
      }
    }
  }

  $scope.redeployNode = function(){
    if($scope.device){
      if($scope.redeployConfirmId){
        if($scope.device.id == $scope.redeployConfirmId){
          $http.get('/api/provision/'+$scope.device.id+'/boot/install').success(function(){
            $scope.reload();
          })
        }
      }
    }
  }

  $window.setInterval($scope.updateAlertAge, 1000);
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