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

module TestRFlowGraphs
using Base.Test

using Catlab.Diagram
using OpenDiscCore
import ..IntegrationTest: db

const r_pkg_dir = readstring(`Rscript -e 'cat(find.package("opendisc"))'`)
const r_raw_graph_dir = joinpath(r_pkg_dir, "tests", "testthat", "data")
const semantic_graph_dir = joinpath(@__DIR__, "data")

# Raw flow graph
################

function read_r_flow_graph(name::String)
  raw_graph = read_raw_graph_file(joinpath(r_raw_graph_dir, "$name.xml"))
  rem_literals!(raw_graph)
end

# Semantic flow graph
#####################

function create_r_semantic_graph(db::OntologyDB, name::String; kw...)
  raw_graph = read_r_flow_graph(name)
  semantic_graph = to_semantic_graph(db, raw_graph; kw...)
  open(joinpath(semantic_graph_dir, "r_$name.xml"), "w") do io
    print(io, write_graphml(semantic_graph))
  end
  semantic_graph
end

# K-means clustering on the Iris dataset using base R.
semantic = create_r_semantic_graph(db, "clustering_kmeans"; elements=false)

end
