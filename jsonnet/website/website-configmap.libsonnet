{

name:: error "name is required",
namespace:: error "namespace is required",

"apiVersion": "v1",
"kind": "ConfigMap",
"metadata": {
  "name": $.name,
  "namespace": $.namespace
}
}
