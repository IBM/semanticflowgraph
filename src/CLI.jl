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

""" Command-line interface for raw and semantic flow graphs.
"""
module CLI
export main

using ArgParse
import DefaultApplication
using Requires

using Catlab.Diagram
import Catlab.Diagram: Graphviz
using ..RawFlowGraphs
using ..SemanticEnrichment
using ..Serialization

# CLI arguments
###############

const settings = ArgParseSettings()

@add_arg_table settings begin
  "record"
    help = "record code as raw flow graph"
    action = :command
  "enrich"
    help = "convert raw flow graph to semantic flow graph"
    action = :command
  "visualize"
    help = "visualize flow graph"
    action = :command
end

@add_arg_table settings["record"] begin
  "path"
    help = "input file or directory"
    required = true
  "-o", "--out"
    help = "output file or directory"
end

@add_arg_table settings["enrich"] begin
  "path"
    help = "input file or directory"
    required = true
  "-o", "--out"
    help = "output file or directory"
end

@add_arg_table settings["visualize"] begin
  "path"
    help = "input file or directory"
    required = true
  "-o", "--out"
    help = "output file or directory"
  "-t", "--to"
    help = "Graphviz output format (default: Graphviz input only)"
  "--raw"
    help = "read input as raw flow graph (default: semantic flow graph)"
    action = :store_true
  "--open"
    help = "open output using OS default application"
    action = :store_true
end

""" Map CLI input/output arguments to pairs of input/output files.
"""
function parse_io_args(input::String, output::Union{String,Nothing}, exts::Dict)
  if isdir(input)
    inexts = collect(keys(exts))
    names = filter(name -> any(endswith.(name, inexts)), readdir(input))
    inputs = [ joinpath(input, name) for name in names ]
    outdir = if output == nothing; input
      elseif isdir(output); output
      else; throw(ArgParseSettings(
        "Output must be directory when input is directory"))
      end
    outputs = [ map_ext(joinpath(outdir, name), exts) for name in names ]
  elseif isfile(input)
    inputs = [ input ]
    outputs = [ output == nothing ? map_ext(input, exts) : output ]
  else
    throw(ArgParseError("Input must be file or directory"))
  end
  collect(zip(inputs, outputs))
end

function map_ext(name::String, ext::Dict)
  # Don't use splitext because we allow extensions with multiple dots.
  for (inext, outext) in ext
    if endswith(name, inext)
      return string(name[1:end-length(inext)], outext)
    end
  end
end

# Record
########

function record(args::Dict)
  langs = Dict(
    ".py" => :python,
    ".R" => :r,
  )
  paths = parse_io_args(args["path"], args["out"], Dict(
    ".py" => ".py.graphml",
    ".R" => ".R.graphml",
  ))
  for (inpath, outpath) in paths
    ext = last(splitext(inpath))
    lang = get(langs, ext) do
      throw(ArgParseError("Unsupported file extension: $ext"))
    end
    record_file(inpath, outpath, Val(lang))
  end
end

function record_file(inpath::String, outpath::String, ::Val{lang}) where lang
  if lang == :python
    error("PyCall.jl has not been imported")
  elseif lang == :r
    error("RCall.jl has not been imported")
  else
    error("Unsupported language: $lang")
  end
end

# Enrich
########

function enrich(args::Dict)
  paths = parse_io_args(args["path"], args["out"], Dict(
    ".py.graphml" => ".graphml",
    ".R.graphml" => ".graphml",
  ))
  db = OntologyDB()
  load_concepts(db)
  for (inpath, outpath) in paths
    raw = read_raw_graph(inpath)
    semantic = to_semantic_graph(db, raw)
    GraphML.write_graphml(semantic, outpath)
  end
end

# Visualize
###########

function visualize(args::Dict)
  format = args["to"] == nothing ? "dot" : args["to"]
  paths = parse_io_args(args["path"], args["out"], Dict(
    ".graphml" => ".$format",
    ".xml" => ".$format",
  ))
  for (inpath, outpath) in paths
    # Read flow graph and convert to Graphviz AST.
    graphviz = if args["raw"]
      raw_graph_to_graphviz(read_raw_graph(inpath))
    else
      semantic_graph_to_graphviz(read_semantic_graph(inpath; elements=false))
    end

    # Pretty-print Graphviz AST to output file.
    if args["to"] == nothing
      # Default: no output format, yield Graphviz dot input.
      open(outpath, "w") do f
        Graphviz.pprint(f, graphviz)
      end
    else
      # Run Graphviz with given output format.
      open(`dot -T$format -o $outpath`, "w", stdout) do f
        Graphviz.pprint(f, graphviz)
      end
    end
    if args["open"]
      DefaultApplication.open(outpath)
    end
  end
end

function raw_graph_to_graphviz(diagram::WiringDiagram)
  to_graphviz(rem_unused_ports(diagram);
    graph_name = "raw_flow_graph",
    labels = true,
    label_attr = :xlabel,
    graph_attrs = Graphviz.Attributes(
      :fontname => "Courier",
    ),
    node_attrs = Graphviz.Attributes(
      :fontname => "Courier",
    ),
    edge_attrs = Graphviz.Attributes(
      :fontname => "Courier",
      :arrowsize => "0.5",
    )
  )
end

function semantic_graph_to_graphviz(diagram::WiringDiagram)
  to_graphviz(diagram;
    graph_name = "semantic_flow_graph",
    labels = true,
    label_attr = :xlabel,
    graph_attrs=Graphviz.Attributes(
      :fontname => "Helvetica",
    ),
    node_attrs=Graphviz.Attributes(
      :fontname => "Helvetica",
    ),
    edge_attrs=Graphviz.Attributes(
      :fontname => "Helvetica",
      :arrowsize => "0.5",
    ),
    cell_attrs=Graphviz.Attributes(
      :style => "rounded",
    )
  )
end

# CLI main
##########

const command_table = Dict(
  "record" => record,
  "enrich" => enrich,
  "visualize" => visualize,
)

function main(args)
  parsed_args = parse_args(args, settings)
  command = parsed_args["%COMMAND%"]
  command_table[command](parsed_args[command])
end

# CLI extras
############

function __init__()
  @require PyCall="438e738f-606a-5dbb-bf0a-cddfbfd45ab0" include("extras/CLI-Python.jl")
  @require RCall="6f49c342-dc21-5d91-9882-a32aef131414" include("extras/CLI-R.jl")
end

end
