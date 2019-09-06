local tekton_taskrun = import './libraries/tekton-taskrun.libsonnet';
local tekton_task = import './libraries/tekton-task.libsonnet';
local Kube = import "../kube.libsonnet";

local buildname = std.extVar('BUILD_NAME');
local imagetag = std.extVar('IMAGE_TAG');

    {

namespace:: 'cicd',

cicd_namespace: Kube.Namespace($.namespace),

task: tekton_task {
    name: std.join("-", ["t","pullcodeandpushtogcr"]),
    namespace: $.namespace,
    buildname: buildname,
},

taskrun: tekton_taskrun {
    name: std.join("-", ["tr",$.task.name,buildname,imagetag]),
    namespace: $.namespace,
    taskref: $.task.name,
    buildname: buildname,
},

    }
