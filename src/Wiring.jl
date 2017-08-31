module Wiring
export to_wiring_diagram

import JSON
using LightXML: XMLDocument

using Catlab
using Catlab.Diagram
import Catlab.Diagram.Wiring: Box, WiringDiagram, to_wiring_diagram,
  validate_ports

using ..Doctrine

# Monocl
########

function Box(f::Monocl.Hom)
  Box(f, collect(dom(f)), collect(codom(f)))
end
function WiringDiagram(dom::Monocl.Ob, codom::Monocl.Ob)
  WiringDiagram(collect(dom), collect(codom))
end

function to_wiring_diagram(expr::Monocl.Hom)
  functor((Ports, WiringDiagram), expr;
    terms = Dict(
      :Ob => (expr) -> Ports([expr]),
      :Hom => (expr) -> WiringDiagram(expr),
      :coerce => (expr) -> WiringDiagram(expr),
      :construct => (expr) -> WiringDiagram(expr),
    )
  )
end

# XXX: Implicit conversion is not implemented, so we disable domain checks.
function validate_ports(source::Monocl.Ob, target::Monocl.Ob) end

# Graphviz support.
GraphvizWiring.label(box::Box{Monocl.Hom{:coerce}}) = "to"
GraphvizWiring.node_id(box::Box{Monocl.Hom{:coerce}}) = ":coerce"

GraphvizWiring.label(box::Box{Monocl.Hom{:construct}}) = string(codom(box.value))
GraphvizWiring.node_id(box::Box{Monocl.Hom{:construct}}) = ":construct"

# Semantic flow graph
#####################

""" Object in the category of elements of the Monocl language.

This type is the value type of wires in the semantic flow graph.
"""
struct MonoclElement
  ob::Monocl.Ob
  value::Any
end

# Raw flow graph
################

struct RawNode
  annotation::Nullable{String}
  language::Dict{String,Any}
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

""" Read raw flow graph from GraphML.
"""
function read_raw_graph(xdoc::XMLDocument)
  GraphML.read_graphml(RawNode, RawPort, RawWire, xdoc)
end

function GraphML.convert_from_graphml_data(::Type{RawNode}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  RawNode(annotation, data)
end

function GraphML.convert_from_graphml_data(::Type{RawPort}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  value = pop!(data, "value", nothing)
  RawPort(annotation, data, value)
end

function GraphML.convert_from_graphml_data(::Type{RawWire}, data::Dict)
  annotation = Nullable{String}(pop!(data, "annotation", nothing))
  id = pop!(data, "id")
  value = pop!(data, "value", nothing)
  RawWire(annotation, data, id, value)
end

# JSON data in GraphML.
# FIXME: Should this functionality be in Catlab?
GraphML.read_graphml_data_value(::Type{Val{:json}}, x::String) = JSON.parse(x)

end
