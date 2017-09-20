module Wiring
export to_wiring_diagram, read_raw_graph, read_raw_graph_file

import JSON
import LightXML

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
validate_ports(source::Monocl.Ob, target::Monocl.Ob) = nothing

# Graphviz support.
GraphvizWiring.label(box::Box{Monocl.Hom{:coerce}}) = "to"
GraphvizWiring.node_id(box::Box{Monocl.Hom{:coerce}}) = ":coerce"

GraphvizWiring.label(box::Box{Monocl.Hom{:construct}}) = string(codom(box.value))
GraphvizWiring.node_id(box::Box{Monocl.Hom{:construct}}) = ":construct"

# TikZ support.
function TikZWiring.box(name::String, f::Monocl.Hom{:generator})
  TikZWiring.rect(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:mcopy})
  TikZWiring.junction_circle(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:delete})
  TikZWiring.junction_circle(name, f)
end
function TikZWiring.box(name::String, f::Monocl.Hom{:coerce})
  TikZWiring.trapezium(
    name,
    "to",
    TikZWiring.wires(dom(f)),
    TikZWiring.wires(codom(f))
  )
end
function TikZWiring.box(name::String, f::Monocl.Hom{:construct})
  TikZWiring.rect(
    name,
    string(codom(f)),
    TikZWiring.wires(dom(f)),
    TikZWiring.wires(codom(f))
  )
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
  RawNode(annotation, data)
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

# JSON data in GraphML.
# FIXME: Should this functionality be in Catlab?
GraphML.read_graphml_data_value(::Type{Val{:json}}, x::String) = JSON.parse(x)

end
