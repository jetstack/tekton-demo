{

name:: error "name is required",
namespace:: error "namespace is required",
type:: error "type is required",
url_value:: error "url_value is required",

  "apiVersion": "tekton.dev/v1alpha1",
  "kind": "PipelineResource",
  "metadata": {
    "name": $.name,
    "namespace": $.namespace
  },
  "spec": {
    "type": $.type,
    "params": [
      {
        "name": "url",
        "value": $.url_value
      },
    ]
  }

}
