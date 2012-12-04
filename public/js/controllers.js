function DefaultController($scope){

}

function NavigationController($scope, $http, $route, $routeParams, Summary){
//get site summary
  Summary.query({
    field: 'site'
  }, function(data){
    $scope.sites = data;
  });
}

function SearchController($scope, $http, Query){
  $scope.results = null;

  $scope.$watch('query', function(){
    $scope.runQuery();
  });


  $scope.runQuery = function(query){
    if(query) $scope.query = query;

    if($scope.query && $scope.query.length > 2){
      var q = $scope.query.split(':');
      var field = (q.length > 1 ? q[0] : 'id:name:aliases');
      q = (q[1] || q[0]).trim();
      q = q.replace('*', '~');

      console.log(q);

      Query.query({
        query: field+'/'+q
      }, function(data){
        $scope.results = (data.length > 0 ? data : null);
      });
    }else{
      $scope.clearResults();
    }
  };

  $scope.clearResults = function(){
    $scope.results = null;
  };
}

function QueryController($scope, $http, $route, $routeParams, Query){
  $scope.query = $routeParams.query.replace(/\|/g, '/');
  $scope.params = $route.current.$route.params;

//run arbitrary query
  if($scope.query){
    Query.query({
      query: $scope.query
    }, function(data){
      $scope.devices = data;
    });
  }
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


function DeviceListController($scope, $http, $timeout, $filter, Device, DeviceNote){
  $scope.sortField = 'name';

  $scope.note_tip_options = function(notes){
    return {
      placement: 'left',
      trigger: 'hover',
      delay: 250,
      html: true,
      content: (function(){
        var rv = '<ul class="notes-tip">';

        for(var time in notes){
          rv += '<li><b>'+$filter('date')((time*1000), 'short')+':</b> '+notes[time].body+'</li>';
        }

        rv += '</ul>';
        return rv;
      })()
    }
  };

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
    $.each($scope.devices, function(idx, i){
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
  }, function(data){
    $scope.devices = data;
  });

  $scope.addRack = function(){
    $scope.racks.push({
      'id': 'Untitled'
    })
  }

  $scope.saveRack = function(rack, old){
    delete rack.editing;
    var devices = [];

    console.log(rack.id, rack.old)
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
    $scope.devices = data;
  });
}

function NodeController($scope, $http, $routeParams, Device, DeviceNote, DeviceStat){
  $scope.id = $routeParams.id;
  $scope.note = null;
  $scope.hidAsAColor = false;

  $scope.reload = function(id){
    var id = id || $scope.id;

    Device.get({
      id: id
    }, function(data){
      $scope.device = data;
    });

    DeviceStat.get({
      id: id
    }, function(data){
      $scope.stats = data;
    })
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