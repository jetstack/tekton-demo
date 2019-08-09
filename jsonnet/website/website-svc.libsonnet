{

name:: error "name is required",
namespace:: error "namespace is required",

"apiVersion": "v1",
"kind": "Service",
"metadata": {
  "name": $.name,
  "namespace": $.namespace
},
"spec": {
  "type": "LoadBalancer",
  "ports": [
    {
      "port": 80,
      "targetPort": 8080
    }
  ],
  "selector": {
    "app": $.name
  }
}
}