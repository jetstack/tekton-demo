local website_service = import "website-svc.libsonnet";
local website_deployment = import "website-deploy.libsonnet";
local website_configmap = import "website-configmap.libsonnet";
local Kube = import "../kube.libsonnet";

local registry = std.extVar('GCR_REGISTRY');
local buildname = std.extVar('BUILD_NAME');
local imagename = std.join("/", [registry, buildname]);
local imageversion = std.extVar('IMAGE_TAG');
local fullimagename = std.join(":", [imagename, imageversion]);

    {

namespace:: 'website-dev',

a_website_namespace: Kube.Namespace($.namespace), // name begins with 'a' to ensure it is applied first

website_service: website_service {
  name: "hello-kubernetes",
  namespace: $.namespace,
},

website_deployment: website_deployment {
  name: $.website_service.name,
  namespace: $.namespace,
  image: fullimagename,
  spec+: {
    template+: {
      spec+: {
        containers+: [{
            name+: $.website_service.name,
            image+: fullimagename,
            envFrom+: [{ configMapRef+: { name: $.website_configmap.name } }],
            ports+: [{
              containerPort+: 8080
        },],
        }]}}}
},

website_configmap: website_configmap {
  name: "cm-hello-kubernetes",
  namespace: $.namespace,
  // data+: { MESSAGE: "Hello, Kubernetes" },
},

    }
