'use strict';

/* Services */

angular.module('assetsService', ['ngResource']).
factory('Summary', function($resource){
  return $resource('/api/devices/summary/by-:field', {
    field: '@field'
  });
}).
factory('List', function($resource){
  return $resource('/api/devices/list/:field', {
    field: '@field'
  });
}).
factory('Query', function($resource){
  return $resource('/api/devices/find/tags/!disabled', {
    query: '@query'
  });
}).
factory('Device', function($resource){
  return $resource('/api/devices/:id', {
    id:       '@id',
    children: true
  });
}).
factory('DeviceNote', function($resource){
  return $resource('/api/devices/:id/notes', {
    id: '@id',
    severity: 'info'
  });
}).
factory('DeviceStat', function($resource){
  return $resource('/api/devices/:id/stats', {
    id: '@id',
    severity: 'info'
  });
}).
factory('Site', function($resource){
  return $resource('/api/devices/summary/by-site/rack/model/fqdn/?where=site/:site', {
    site: '@site'
  });
}).
factory('SiteContact', function($resource){
  return $resource('/api/org/contacts/find/site/:site', {
    site: '@site'
  });
}).
factory('Rack', function($resource){
  return $resource('/api/devices/summary/by-unit/fqdn/?where=site/:site/rack/:rack', {
    site: '@site',
    rack: '@rack'
  });
});
