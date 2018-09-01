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

module IntegrationTest
using Test

using SemanticFlowGraphs

# Load all concepts in the ontology at the outset.
const db = OntologyDB()
load_concepts(db)

# Run integration tests.
@testset "PyFlowGraphs" begin
  include("PyFlowGraphs.jl")
end
@testset "RFlowGraphs" begin
  include("RFlowGraphs.jl")
end

end
