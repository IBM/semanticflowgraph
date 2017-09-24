module FlowGraph
export RawNode, RawPort, RawWire, read_raw_graph, read_raw_graph_file,
  to_semantic_graph

import JSON
import LightXML
using Parameters

using Catlab.Diagram
using ..Doctrine
using ..Ontology

# Raw flow graph
################

@with_kw struct RawNode
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  slot::Bool = false
end

@with_kw struct RawPort
  language::Dict{String,Any} = Dict{String,Any}()
  annotation::Nullable{String} = Nullable{String}()
  index::Nullable{Int} = Nullable()
  value::Nullable = Nullable()
end

@with_kw struct RawWire
  language::Dict{String,Any} = Dict{String,Any}()
  id::Nullable{String} = Nullable{String}()
  value::Nullable = Nullable()
end

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
  RawNode(data, annotation, slot)
end

function GraphML.convert_from_graphml_data(::Type{RawPort}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  annotation_index = Nullable{Int}(pop!(data, "annotation_index", nothing))
  value = pop!(data, "value", Nullable())
  RawPort(data, annotation, annotation_index, value)
end

function GraphML.convert_from_graphml_data(::Type{RawWire}, data::Dict)
  pop!(data, "annotation", nothing) # Get object annotation from port, not wire.
  id = Nullable{String}(pop!(data, "id", nothing))
  value = pop!(data, "value", Nullable())
  RawWire(data, id, value)
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
  # Expand the function definition as a wiring diagram and permute the
  # incoming and outoging wires.
  note = annotation(db, get(node.annotation))::HomAnnotation
  f = WiringDiagram(inputs, outputs)
  v = add_box!(f, to_wiring_diagram(note.definition))
  add_wires!(f, ((input_id(f), i) => (v, get(port.index))
                 for (i, port) in enumerate(inputs) if !isnull(port.index)))
  add_wires!(f, ((v, get(port.index)) => (output_id(f), i)
                 for (i, port) in enumerate(outputs) if !isnull(port.index)))
  substitute!(f, v)
  return f
end

end
