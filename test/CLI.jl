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

module TestCLI
using Test
import JSON

import SemanticFlowGraphs: CLI

const data_dir = joinpath(@__DIR__, "data")
const test_py = false
const test_r = false

mktempdir() do dir
  # Visualize raw flow graph.
  inpath = joinpath(data_dir, "clustering_kmeans.R.graphml")
  outpath = joinpath(dir, "clustering_kmeans.R.dot")
  CLI.main(["visualize", "--raw", inpath, "--out", outpath])
  @test isfile(outpath)

  # Convert raw flow graph to semantic flow graph.
  outpath = joinpath(dir, "clustering_kmeans.graphml")
  CLI.main(["enrich", inpath, "--out", outpath])
  @test isfile(outpath)

  # Visualize semantic flow graph.
  inpath = outpath
  outpath = joinpath(dir, "clustering_kmeans.dot")
  CLI.main(["visualize", inpath, "--out", outpath])
  @test isfile(outpath)
end

mktempdir() do dir
  # Export concepts as JSON.
  outpath = joinpath(dir, "concepts.json")
  CLI.main(["ontology", "json", "--no-annotations", "--out", outpath])
  @test isfile(outpath)
  @test JSON.parsefile(outpath) isa AbstractVector
end

mktempdir() do dir
  # Export concepts as RDF/OWL.
  outpath = joinpath(dir, "concepts.ttl")
  CLI.main(["ontology", "rdf", "--no-annotations", "--out", outpath])
  @test isfile(outpath)
end

if test_py
  import PyCall

  mktempdir() do dir
    # Record Python raw flow graph.
    inpath = joinpath(data_dir, "sklearn_clustering_kmeans.py")
    outpath = joinpath(dir, "sklearn_clustering_kmeans.py.graphml")
    CLI.main(["record", inpath, "--out", outpath])
    @test isfile(outpath)
  end
end

if test_r
  import RCall

  mktempdir() do dir
    # Record R raw flow graph.
    inpath = joinpath(data_dir, "clustering_kmeans.R")
    outpath = joinpath(dir, "clustering_kmeans.R.graphml")
    CLI.main(["record", inpath, "--out", outpath])
    @test isfile(outpath)
  end
end

end
