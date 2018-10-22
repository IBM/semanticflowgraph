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

# Reduce load time by only importing PyCall and/or RCall if the "record"
# command is being invoked.
if length(ARGS) >= 1 && ARGS[1] == "record"
  try
    import PyCall
  catch
  end
  try
    import RCall
  catch
  end
end

CLI.main(ARGS)