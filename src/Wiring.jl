module Wiring
export to_wiring_diagram

import JSON
using LightXML

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
  language::Dict{String,String}
end

struct RawPort
  annotation::Nullable{Int}
  language::Dict{String,String}
  value::Any
end

struct RawWire
  annotation::Nullable{String}
  language::Dict{String,String}
  id::String
  value::Any
end

""" Read raw flow graph from GraphML.
"""
function read_raw_graph(xdoc::XMLDocument)
  GraphML.read_graphml(RawNode, RawWire, RawPort, xdoc)
end

function GraphML.read_graphml_data(xelem::XMLElement, ::Type{RawNode})
  annotation = Nullable{String}()
  language = Dict{String,String}()
  for (key, data) in iter_graphml_data(xelem)
    if key == "annotation"
      annotation = Nullable(data)
    else
      language[key] = data
    end
  end
  RawNode(annotation, language)
end

function GraphML.read_graphml_data(xelem::XMLElement, ::Type{RawPort})
  annotation = Nullable{Int}()
  language = Dict{String,String}()
  value = nothing
  for (key, data) in iter_graphml_data(xelem)
    if key == "annotation"
      annotation = Nullable(parse(Int, data))
    elseif key == "value"
      value = JSON.parse(data)
    else
      language[key] = data
    end
  end
  RawPort(annotation, language, value)
end

function GraphML.read_graphml_data(xelem::XMLElement, ::Type{RawWire})
  annotation = Nullable{String}()
  language = Dict{String,String}()
  id = Nullable{String}()
  value = nothing
  for (key, data) in iter_graphml_data(xelem)
    if key == "annotation"
      annotation = Nullable(data)
    elseif key == "id"
      id = Nullable(data)
    elseif key == "value"
      value = JSON.parse(data)
    else
      language[key] = data
    end
  end
  RawWire(annotation, language, get(id), value)
end

function iter_graphml_data(xelem::XMLElement)
  ((attribute(xdata, "key") => content(xdata)) for xdata in xelem["data"])
end

end
