module TestWiring
using Base.Test

import Catlab.Diagram: Graphviz
using Catlab.Diagram: Wiring, GraphvizWiring
using OpenDiscCore: Doctrine, Wiring

# Abstract wiring diagrams
##########################

A0, A, B0, B = Ob(Monocl, :A0, :A, :B0, :B)
f = Hom(:f, A, B)
g = Hom(:g, B, A)

diagram = to_wiring_diagram(f)
@test boxes(diagram) == [ Box(f) ]
@test input_ports(diagram) == [ A ]
@test output_ports(diagram) == [ B ]

coercion = coerce(SubOb(A0, A))
diagram = to_wiring_diagram(compose(coercion, f))
@test boxes(diagram) == [ Box(coercion), Box(f) ]
@test input_ports(diagram) == [ A0 ]
@test output_ports(diagram) == [ B ]

# Graphviz wiring diagrams
##########################

diagram = to_wiring_diagram(compose(coerce(SubOb(A0,A)), construct(g)))
@test isa(to_graphviz(diagram), Graphviz.Graph)

end
