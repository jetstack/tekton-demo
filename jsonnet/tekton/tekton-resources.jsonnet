local tekton_resource = import './libraries/tekton-pipeline-rsc.libsonnet';
local Kube = import "../kube.libsonnet";

local buildname = std.extVar('BUILD_NAME');
local registry = std.extVar('GCR_REGISTRY');
local imageversion = std.extVar('IMAGE_TAG');
local gitrepourl = std.extVar('GIT_REPO_URL');

local imgrsc = (std.join("-", ["img", buildname] ) );
local imagename = std.join("/", [registry, buildname]);
local fullimagename = std.join(":", [imagename, imageversion]);

    {

namespace:: 'cicd',

cicd_namespace: Kube.Namespace($.namespace),

git_resource: tekton_resource {
    name: (std.join("-",["git", buildname])),
    namespace: $.namespace,
    type: "git",
    url_value: gitrepourl,
    spec+: {
        params+: [{
          "name": "revision",
          "value": "master"
        }]
    }
},

gcr_resource: tekton_resource {
    name: (std.join("-",["img", buildname])),
    namespace: $.namespace,
    type: "image",
    url_value: fullimagename,
},

    }
