{

name:: error "name is required",
namespace:: error "namespace is required",
image:: error "image is required",

  "apiVersion": "apps/v1",
  "kind": "Deployment",
  "metadata": {
    "name": $.name,
    "namespace": $.namespace
  },
  "spec": {
    "replicas": 3,
    "strategy": {
      "type": "RollingUpdate",
      "rollingUpdate": {
        "maxSurge": 0,
        "maxUnavailable": 1
      }
    },
    "selector": {
      "matchLabels": {
        "app": $.metadata.name
      }
    },
    "template": {
      "metadata": {
        "labels": {
          "app": $.metadata.name
        }
      },
      "spec": {
        "affinity": {
          "nodeAffinity": {
            "requiredDuringSchedulingIgnoredDuringExecution": {
              "nodeSelectorTerms": [
                {
                  "matchExpressions": [
                    {
                      "key": "cloud.google.com/gke-nodepool",
                      "operator": "In",
                      "values": [
                        "web-backend"
                      ]
                    }
                  ]
                }
              ]
            }
          }
        }
      }
    }
  }
}
