function GlobalController($scope){

}

function NavigationController($scope, $location){
  $scope.navbar = [{
    title: 'About',
    path:  '/',
    icon:  'home'
  },{
    title: 'Documentation',
    path:  '/docs',
    icon:  'book'
  },{
    title: 'Download',
    path:  '/download',
    icon:  'download-alt',
    disabled: true
  },{
    title: 'Contact',
    path:  '/contact',
    icon:  'bullhorn',
    disabled: true
  }];

  $scope.getActive = function(path){
    if((path == '/' && $location.path() == '/') ||
       (path != '/' && $location.path().match(new RegExp('^'+path)))){
      return true;
    }

    return false;
  }
}

function PageIndexController($scope){

}

function PageDocsController($scope, $location, $anchorScroll){
  $scope.topic = {
    topics: [{
      link:  'Getting Started',
      path:  'gs',
      topics: [{
        prefix: 'gs',
        link:   'Requirements'
      },{
        prefix: 'gs',
        link:   'Installation'
      },{
        prefix: 'gs',
        link:   'Receiving Data',
        title:  'Receiving Data From Clients'
      }]
    },{
      link: 'Using the Frontend',
      path: 'fe'
    }]
  };

  $scope.scrollTo = function(id) {
    console.log("JUMP", id)
    $location.hash(id);
    $anchorScroll();
  }

  $scope.hasChildren = function(topic){
    if(angular.isArray(topic.topics)){
      return true;
    }

    return false;
  }

  $scope.nameToPath = function(name, prefix){
    if(angular.isDefined(prefix)){
      name = prefix+'-'+name;
    }

    return name.toLowerCase().replace(/[ ]+/g, '-');
  }
}
