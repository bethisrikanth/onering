function HarbormasterTasksController($scope){
  $scope.mock_tasks = [{
    name: "onering-worker",
    running:   47,
    instances: 48,
    framework: {
      name: "marathon",
      executor: "docker",
      details: {
        title: "ops/onering-worker:latest"
      }
    },
    resources: {
      cpu: 2,
      memory: 2
    }
  },{
    name: "onering-api",
    running:   22,
    instances: 24,
    framework: {
      name: "marathon",
      executor: "docker",
      details: {
        title: "ops/onering-api:latest"
      }
    },
    resources: {
      cpu: 2,
      memory: 2
    }
  },{
    name: "onering-redis",
    running:   1,
    instances: 1,
    framework: {
      name: "marathon",
      executor: "docker",
      details: {
        title: "base/redis:latest"
      }
    },
    resources: {
      cpu: 2,
      memory: 4
    }
  },{
    name: "onering-resque-web",
    running:   1,
    instances: 1,
    framework: {
      name: "marathon",
      executor: "docker",
      details: {
        title: "ops/onering-resque-web:latest"
      }
    },
    resources: {
      cpu: 2,
      memory: 1
    }
  }];
}