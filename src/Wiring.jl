module Wiring
export to_wiring_diagram

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

end
