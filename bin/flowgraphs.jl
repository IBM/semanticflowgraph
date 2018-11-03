#!/usr/bin/env julia

# Copyright 2018 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import SemanticFlowGraphs: CLI

function expand_paths(path::String)::Vector{String}
  if isfile(path); [ path ]
  elseif isdir(path); readdir(path)
  else String[] end
end

cmd, cmd_args = CLI.parse(ARGS)

# XXX: Reduce load time by only importing extra packages as needed.
# Julia really needs a better solution to this problem...
if cmd == "record"
  paths = expand_paths(cmd_args["path"])
  if any(endswith(path, ".py") for path in paths)
    import PyCall
  end
  if any(endswith(path, ".R") for path in paths)
    import RCall
  end
end

CLI.invoke(cmd, cmd_args)
