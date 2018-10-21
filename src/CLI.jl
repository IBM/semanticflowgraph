using ArgParse

using Catlab.Diagram
import Catlab.Diagram: Graphviz
using SemanticFlowGraphs

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
  "--raw"
    help = "read input as raw flow graph (default: semantic flow graph)"
    action = :store_true
  "-o", "--out"
    help = "output file or directory"
  "-t", "--to"
    help = "Graphviz output format (default: Graphviz input only)"
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

function record(args)
  paths = parse_io_args(args["path"], args["out"], Dict(
    ".py" => ".py.graphml",
    ".R" => ".R.graphml",
  ))
end

# Enrich
########

function enrich(args)
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

function visualize(args)
  format = args["to"] == nothing ? "dot" : args["to"]
  paths = parse_io_args(args["path"], args["out"], Dict(
    ".graphml" => ".$format",
    ".xml" => ".$format",
  ))
  for (inpath, outpath) in paths
    graphviz = if args["raw"]
      raw_graph_to_graphviz(read_raw_graph(inpath))
    else
      semantic_graph_to_graphviz(read_semantic_graph(inpath; elements=false))
    end
    if args["to"] == nothing
      # Default: no output format, yield Graphviz dot input.
      open(outpath, "w") do f
        Graphviz.pprint(f, graphviz)
      end
    else
      # Run Graphviz with given output format.
      open(`dot -T$format -ofile $outpath`, "w", stdout) do f
        Graphviz.pprint(f, graphviz)
      end
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

if @__MODULE__() == Main
  main(ARGS)
end