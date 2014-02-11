---
---
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
    icon:  'book',
    items: [{
      title: 'Getting Started',
      path:  '/docs'
    },{
      title: 'API Reference',
      path:  '/docs/reference'
    }]
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

function PageDocsController($scope, $http, $location, $anchorScroll){
  $http.get('{{ site.url_prefix }}/api/docs/topics.json').success(function(data){
    $scope.topic = data;
  });

  $scope.scrollTo = function(id) {
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

function PageReferenceController($scope, $routeParams){
  $scope.plugin = $routeParams.plugin;
}
