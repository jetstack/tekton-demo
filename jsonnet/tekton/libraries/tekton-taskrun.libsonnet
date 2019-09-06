{

name:: error "name is required",
namespace:: error "namespace is required",
taskref:: error "taskref is required",
buildname:: error "buildname is required",

  "apiVersion": "tekton.dev/v1alpha1",
  "kind": "TaskRun",
  "metadata": {
    "name": $.name,
    "namespace": $.namespace,
  },
  "spec": {
    "taskRef": {
      "name": $.taskref,
    },
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
                "cicd"
              ]
            }
          ]
          }
      ]
    }
    }
    },
    "inputs": {
      "resources": [
        {
          "name": (std.join("-", ["git", $.buildname])),
          "resourceRef": {
            "name": (std.join("-", ["git", $.buildname])),
          }
        }
      ],
      "params": [
        {
          "name": "pathToDockerFile",
          "value": (std.join("/", ["/workspace", std.join("-", ["git", $.buildname]), "Dockerfile"])),
        },
        {
          "name": "pathToContext",
          "value": (std.join("/", ["/workspace", std.join("-", ["git", $.buildname])])),
        }
      ]
    },
    "outputs": {
      "resources": [
        {
          "name": "builtImage",
          "resourceRef": {
            "name": (std.join("-", ["img", $.buildname]))
          }
        }
      ]
    }
  }
}