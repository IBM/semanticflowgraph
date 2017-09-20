module FlowGraph
export read_raw_graph, read_raw_graph_file, to_semantic_graph

import JSON
import LightXML

using Catlab.Diagram
import Catlab.Diagram.Wiring: validate_ports
using ..Doctrine
using ..Ontology

# Raw flow graph
################

struct RawNode
  annotation::Nullable{String}
  language::Dict{String,Any}
  slot::Bool
end

struct RawPort
  annotation::Nullable{Int}
  language::Dict{String,Any}
  value::Any
end

struct RawWire
  annotation::Nullable{String}
  language::Dict{String,Any}
  id::String
  value::Any
end

# Do not validate raw ports: there is nothing that must match.
validate_ports(source::RawPort, target::RawPort) = nothing

""" Read raw flow graph from GraphML.
"""
function read_raw_graph(xdoc::LightXML.XMLDocument)
  GraphML.read_graphml(RawNode, RawPort, RawWire, xdoc)
end
read_raw_graph(xml::String) = read_raw_graph(LightXML.parse_string(xml))
read_raw_graph_file(args...) = read_raw_graph(LightXML.parse_file(args...))

function GraphML.convert_from_graphml_data(::Type{RawNode}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  slot = haskey(data, "slot")
  RawNode(annotation, data, slot)
end

function GraphML.convert_from_graphml_data(::Type{RawPort}, data::Dict)
  annotation = Nullable{Int}(pop!(data, "annotation", nothing))
  value = pop!(data, "value", nothing)
  RawPort(annotation, data, value)
end

function GraphML.convert_from_graphml_data(::Type{RawWire}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  id = pop!(data, "id")
  value = pop!(data, "value", nothing)
  RawWire(annotation, data, id, value)
end

# Support JSON data in GraphML.
# FIXME: Should this functionality be in Catlab?
GraphML.read_graphml_data_value(::Type{Val{:json}}, x::String) = JSON.parse(x)

# Semantic flow graph
#####################

""" Convert a raw flow graph into a semantic flow graph.
"""
function to_semantic_graph(db::OntologyDB, raw::WiringDiagram)
  sem = deepcopy(raw)
  expand_annotated_boxes!(db, sem)
  return sem
end

""" Expand annotated boxes in raw graph using definitions in ontology.
"""
function expand_annotated_boxes!(db::OntologyDB, diagram::WiringDiagram)
  expand = Int[]
  expansions = WiringDiagram[]
  for v in box_ids(diagram)
    b = box(diagram, v)
    node = b.value
    if !isnull(node.annotation)
      expansion = expand_annotated_box(db, node, input_ports(b), output_ports(b))
      push!(expand, v)
      push!(expansions, expansion)
    end
  end
  substitute!(diagram, expand, expansions)
end

""" Expand a single annotated box from a raw flow graph.
"""
function expand_annotated_box(db::OntologyDB, node::RawNode,
                              inputs::Vector{RawPort},
                              outputs::Vector{RawPort})::WiringDiagram
  # Special case: slot of annotated object.
  if node.slot
    definition = concept(db, get(node.annotation))::Monocl.Hom
    return to_wiring_diagram(definition)
  end
  
  # General case: annotated function.
  note = annotation(db, get(node.annotation))::HomAnnotation
  dom_perm = Int[ get(p.annotation) for p in inputs if !isnull(p.annotation) ]
  codom_perm = Int[ get(p.annotation) for p in outputs if !isnull(p.annotation) ]
  definition = note.definition
  compose(
    permute(Ports(collect(dom(definition))), dom_perm, inverse=true),
    to_wiring_diagram(definition),
    permute(Ports(collect(codom(definition))), codom_perm),
  )
end

end
