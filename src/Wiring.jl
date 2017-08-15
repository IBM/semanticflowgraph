module Wiring
export to_wiring_diagram

using Catlab
using Catlab.Diagram: Wiring, GraphvizWiring
import Catlab.Diagram.Wiring: Box, WiringDiagram, to_wiring_diagram,
  validate_wire_types

using ..Doctrine

# Abstract wiring diagrams
##########################

function Box(f::Monocl.Hom)
  Box(f, collect(dom(f)), collect(codom(f)))
end
function WiringDiagram(dom::Monocl.Ob, codom::Monocl.Ob)
  WiringDiagram(collect(dom), collect(codom))
end

function to_wiring_diagram(expr::Monocl.Hom)
  functor((WireTypes, WiringDiagram), expr;
    terms = Dict(
      :Ob => (expr) -> WireTypes([expr]),
      :Hom => (expr) -> WiringDiagram(expr),
      :coerce => (expr) -> WiringDiagram(expr),
      :construct => (expr) -> WiringDiagram(expr),
    )
  )
end

function validate_wire_types(source::Monocl.Ob, target::Monocl.Ob)
  # XXX: Implicit conversion is not implemented, so we disable domain checks.
  nothing
end

# Graphviz wiring diagrams
##########################

GraphvizWiring.label(box::Box{Monocl.Hom{:coerce}}) = "coerce"
GraphvizWiring.node_id(box::Box{Monocl.Hom{:coerce}}) = "__coerce__"

GraphvizWiring.label(box::Box{Monocl.Hom{:construct}}) = string(codom(box.value))
GraphvizWiring.node_id(box::Box{Monocl.Hom{:construct}}) = "__construct__"

end
