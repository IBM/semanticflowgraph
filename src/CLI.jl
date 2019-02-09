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
export main, invoke, parse

using ArgParse
import DefaultApplication
using Requires
import JSON
import Serd

using Catlab.WiringDiagrams, Catlab.Graphics
import Catlab.Graphics: Graphviz
using ..RawFlowGraphs
using ..Ontology, ..SemanticEnrichment
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
  "ontology"
    help = "export ontology"
    action = :command
end

@add_arg_table settings["record"] begin
  "path"
    help = "input Python or R file, or directory"
    required = true
  "-o", "--out"
    help = "output raw flow graph or directory"
  "-f", "--from"
    help = "input format (one of: \"python\", \"r\") (default: from file name)"
    default = nothing
  "-t", "--to"
    help = "output format (one of: \"graphml\", \"json\")"
    default = "graphml"
  "--graph-outputs"
    help = "whether and how to retain outputs of raw flow graph (Python only)"
    default = "none"
end

@add_arg_table settings["enrich"] begin
  "path"
    help = "input raw flow graph or directory"
    required = true
  "-o", "--out"
    help = "output semantic flow graph or directory"
  "-f", "--from"
    help = "input format (one of: \"graphml\", \"json\") (default: from file name)"
    default = nothing
  "-t", "--to"
    help = "output format (one of: \"graphml\", \"json\")"
    default = "graphml"
end

@add_arg_table settings["visualize"] begin
  "path"
    help = "input raw or semantic flow graph, or directory"
    required = true
  "-o", "--out"
    help = "output file or directory"
  "-f", "--from"
    help = "input format (one of: \"raw-graphml\", \"raw-json\", \"semantic-graphml\", \"semantic-json\") (default: from file name)"
    default = nothing
  "-t", "--to"
    help = "Graphviz output format (default: Graphviz input only)"
  "--open"
    help = "open output using OS default application"
    action = :store_true
end

@add_arg_table settings["ontology"] begin
  "json"
    help = "export ontology as JSON"
    action = :command
  "rdf"
    help = "export ontology as RDF/OWL"
    action = :command
end

@add_arg_table settings["ontology"]["json"] begin
  "-o", "--out"
    help = "output file (default: stdout)"
  "--indent"
    help = "number of spaces to indent (default: compact output)"
    arg_type = Int
    default = nothing
  "--no-concepts"
    help = "exclude concepts from export"
    dest_name = "concepts"
    action = :store_false
  "--no-annotations"
    help = "exclude annotations from export"
    dest_name = "annotations"
    action = :store_false
end

@add_arg_table settings["ontology"]["rdf"] begin
  "-o", "--out"
    help = "output file (default: stdout)"
  "-t", "--to"
    help = "output format (one of: \"turtle\", \"ntriples\", \"nquads\", \"trig\")"
    default = "turtle"
  "--no-concepts"
    help = "omit concepts"
    dest_name = "concepts"
    action = :store_false
  "--no-annotations"
    help = "omit annotations"
    dest_name = "annotations"
    action = :store_false
  "--no-schema"
    help = "omit preamble defining OWL schema for concepts and annotations"
    dest_name = "schema"
    action = :store_false
  "--no-provenance"
    help = "omit interoperability with PROV Ontology (PROV-O)"
    dest_name = "provenance"
    action = :store_false
  "--no-wiring-diagrams"
    help = "omit wiring diagrams in concepts and annotations"
    dest_name = "wiring"
    action = :store_false
end

# Record
########

function record(args::Dict)
  paths = parse_io_args(args["path"], args["out"],
    format = args["from"],
    formats = Dict(
      ".py" => "python",
      ".r" => "r",
      ".R" => "r",
    ),
    out_ext = format -> ".raw." * args["to"]
  )
  for (inpath, lang, outpath) in paths
    if args["to"] == "graphml"
      record_file(abspath(inpath), abspath(outpath), args, Val(Symbol(lang)))
    else
      # Both the Python and R packages emit GraphML.
      diagram = mktemp() do temp_path, io
        record_file(abspath(inpath), temp_path, args, Val(Symbol(lang)))
        read_graph_file(temp_path, format="graphml")
      end
      write_graph_file(diagram, outpath, format=args["to"])
    end
  end
end

function record_file(inpath::String, outpath::String, args::Dict, 
                     ::Val{lang}) where lang
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
  paths = parse_io_args(args["path"], args["out"],
    format = args["from"],
    formats = Dict(
      ".raw.graphml" => "graphml",
      ".raw.json" => "json",
    ),
    out_ext = format -> ".semantic." * args["to"],
  )
  db = OntologyDB()
  load_concepts(db)
  for (inpath, format, outpath) in paths
    raw = read_graph_file(inpath, kind="raw", format=format)
    raw = rem_literals!(raw)
    semantic = to_semantic_graph(db, raw)
    write_graph_file(semantic, outpath, format=args["to"])
  end
end

# Visualize
###########

function visualize(args::Dict)
  format = args["from"] == nothing ? nothing : Tuple(split(args["from"],"-",1))
  out_format = args["to"] == nothing ? "dot" : args["to"]
  paths = parse_io_args(args["path"], args["out"],
    format = format,
    formats = Dict(
      ".raw.graphml" => ("raw", "graphml"),
      ".raw.json" => ("raw", "json"),
      ".semantic.graphml" => ("semantic", "graphml"),
      ".semantic.json" => ("semantic", "json"),
    ),
    out_ext = format -> "." * first(format) * "." * out_format,
  )
  for (inpath, (kind, format), outpath) in paths
    # Read flow graph and convert to Graphviz AST.
    diagram = read_graph_file(inpath, kind=kind, format=format)
    graphviz = if kind == "raw"
      raw_graph_to_graphviz(diagram)
    else
      semantic_graph_to_graphviz(diagram)
    end

    # Pretty-print Graphviz AST to output file.
    if args["to"] == nothing
      # Default: no output format, yield Graphviz dot input.
      open(outpath, "w") do f
        Graphviz.pprint(f, graphviz)
      end
    else
      # Run Graphviz with given output format.
      open(`dot -T$out_format -o $outpath`, "w", stdout) do f
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

# Ontology
##########

function ontology_as_json(args::Dict)
  docs = AbstractDict[]
  db = OntologyDB()
  if args["concepts"]
    append!(docs, OntologyDBs.api_get(db, "/concepts"))
  end
  if args["annotations"]
    append!(docs, OntologyDBs.api_get(db, "/annotations"))
  end
  if args["out"] != nothing
    open(args["out"], "w") do out
      JSON.print(out, docs, args["indent"])
    end
  else
    JSON.print(stdout, docs, args["indent"])
  end
end

function ontology_as_rdf(args::Dict)
  # Load ontology data from remote database.
  db = OntologyDB()
  if args["concepts"]
    load_concepts(db)
  end
  if args["annotations"]
    load_annotations(db)
  end

  # Load ontology schemas from filesystem.
  stmts = Serd.RDF.Statement[]
  if args["schema"]
    append!(stmts, [
      read_ontology_rdf_schema("list.ttl");
      args["concepts"] ? read_ontology_rdf_schema("concept.ttl") : [];
      args["annotations"] ? read_ontology_rdf_schema("annotation.ttl") : [];
      args["wiring"] ? read_ontology_rdf_schema("wiring.ttl") : [];
    ])
  end

  # Convert to RDF.
  prefix = Serd.RDF.Prefix("dso", "https://www.datascienceontology.org/ns/dso/")
  append!(stmts, ontology_to_rdf(db, prefix,
    include_provenance=args["provenance"],
    include_wiring_diagrams=args["wiring"]))

  # Serialize RDF to file or stdout.
  syntax = args["to"]
  if args["out"] != nothing
    open(args["out"], "w") do out
      Serd.write_rdf(out, stmts, syntax=syntax)
    end
  else
    Serd.write_rdf(stdout, stmts, syntax=syntax)
  end
end

function read_ontology_rdf_schema(name::String)
  Serd.read_rdf_file(joinpath(ontology_rdf_schema_dir, name))
end

const ontology_rdf_schema_dir = joinpath(@__DIR__, "ontology", "rdf", "schema")

# CLI main
##########

function main(args)
  invoke(parse(args)...)
end

function parse(args)
  cmds = String[]
  parsed_args = parse_args(args, settings)
  while haskey(parsed_args, "%COMMAND%")
    cmd = parsed_args["%COMMAND%"]
    parsed_args = parsed_args[cmd]
    push!(cmds, cmd)
  end
  return (cmds, parsed_args)
end

function invoke(cmds, cmd_args)
  try
    cmd_fun = command_table
    for cmd in cmds; cmd_fun = cmd_fun[cmd] end
    cmd_fun(cmd_args)
  catch err
    # Handle further "parsing" errors ala ArgParse.jl.
    isa(err, ArgParseError) || rethrow()
    settings.exc_handler(settings, err)
  end
end

const command_table = Dict(
  "record" => record,
  "enrich" => enrich,
  "visualize" => visualize,
  "ontology" => Dict(
    "json" => ontology_as_json,
    "rdf" => ontology_as_rdf,
  ),
)

# CLI extras
############

function __init__()
  @require PyCall="438e738f-606a-5dbb-bf0a-cddfbfd45ab0" include("extras/CLI-Python.jl")
  @require RCall="6f49c342-dc21-5d91-9882-a32aef131414" include("extras/CLI-R.jl")
end

# CLI utilities
###############

""" Map CLI input/output arguments to pairs of input/output files.
"""
function parse_io_args(input::String, output::Union{String,Nothing};
                       format::Any=nothing, formats::AbstractDict=Dict(),
                       out_ext::Function=format->"")
  function get_format_and_output(input, output=nothing)
    if output == nothing || format == nothing
      name, ext = match_ext(input, keys(formats))
      inferred_format = formats[ext]
      inferred_output = name * out_ext(inferred_format)
    end
    (format == nothing ? inferred_format : format,
     output == nothing ? inferred_output : output)
  end

  if isdir(input)
    inexts = collect(keys(formats))
    names = filter(name -> any(endswith.(name, inexts)), readdir(input))
    outdir = if output == nothing; input
      elseif isdir(output); output
      else; throw(ArgParseError(
        "Output must be directory when input is directory"))
      end
    map(names) do name
      format, output = get_format_and_output(name)
      (joinpath(input, name), format, joinpath(outdir, output))
    end
  elseif isfile(input)
    format, output = get_format_and_output(input, output)
    [ (input, format, output) ]
  else
    throw(ArgParseError("Input must be file or directory"))
  end
end

function match_ext(name::String, exts)
  # Don't use splitext because we allow extensions with multiple dots.
  for ext in exts
    if endswith(name, ext)
      return (name[1:end-length(ext)], ext)
    end
  end
  throw(ArgParseError("Cannot match extension in filename: \"$name\""))
end

function read_graph_file(filename::String;
    kind::Union{String,Nothing}=nothing, format::String="graphml")
  reader = get(graph_readers, (kind, format)) do
    error("Invalid graph kind \"$kind\" or format \"$format\"")
  end
  reader(filename)
end

function write_graph_file(diagram::WiringDiagram, filename::String;
    format::String="graphml")
  writer = get(graph_writers, format) do
    error("Invalid graph format \"$format\"")
  end
  writer(diagram, filename)
end

const graph_readers = Dict(
  (nothing, "graphml") => x -> read_graphml(Dict, Dict, Dict, x),
  (nothing, "json") => x -> read_json_graph(Dict, Dict, Dict, x),
  ("raw", "graphml") => read_raw_graphml,
  ("raw", "json") => read_raw_graph_json,
  ("semantic", "graphml") => read_semantic_graphml,
  ("semantic", "json") => read_semantic_graph_json,
)

const graph_writers = Dict(
  "graphml" => write_graphml,
  "json" => (x, filename) -> write_json_graph(x, filename, indent=2),
)

end
