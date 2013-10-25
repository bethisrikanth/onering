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
    disabled: true
  },{
    title: 'Download',
    path:  '/download',
    icon:  'download-alt',
    disabled: true
  },{
    title: 'Contact',
    path:  '/contact',
    icon:  '',
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

function PageAboutController($scope){

}
