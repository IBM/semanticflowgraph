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

module TestDoctrine
using Test

using Catlab, Catlab.WiringDiagrams, Catlab.Graphics
import Catlab.Graphics: Graphviz
using SemanticFlowGraphs.Doctrine

# Monocl category
#################

A, B, C = Ob(Monocl, :A, :B, :C)
A0, B0, C0, A1, B1, C1 = Ob(Monocl, :A0, :B0, :C0, :A1, :B1, :C1)
I = munit(Monocl.Ob)
f = Hom(:f, A, B)
f0, f1 = Hom(:f0, A0, B0), Hom(:f1, A1, B1)

# Subobjects
subA = SubOb(A0, A)
subB = SubOb(B0, B)
@test dom(subA) == A0
@test codom(subA) == A

sub = compose(SubOb(A0, A), SubOb(A, A1))
@test dom(sub) == A0
@test codom(sub) == A1
@test dom(subob_id(A)) == A
@test codom(subob_id(A)) == A
@test_throws SyntaxDomainError compose(subA, subB)

sub = otimes(subA, subB)
@test dom(sub) == otimes(A0,B0)
@test codom(sub) == otimes(A,B)

# Submorphisms
subf = SubHom(f0, f, subA, subB)
@test dom(subf) == f0
@test codom(subf) == f
@test subob_dom(subf) == subA
@test subob_codom(subf) == subB

subf1 = SubHom(f, f1, SubOb(A, A1), SubOb(B, B1))
sub = compose(subf, subf1)
@test dom(sub) == f0
@test codom(sub) == f1
@test subob_dom(sub) == compose(SubOb(A0,A), SubOb(A,A1))
@test subob_codom(sub) == compose(SubOb(B0,B), SubOb(B,B1))
@test dom(subhom_id(f)) == f
@test codom(subhom_id(f)) == f
@test subob_dom(subhom_id(f)) == subob_id(A)
@test subob_codom(subhom_id(f)) == subob_id(B)

g, g0 = Hom(:g, B, C), Hom(:g0, B0, C0)
subg = SubHom(g0, g, SubOb(B0, B), SubOb(C0, C))
sub = compose2(subf, subg)
@test dom(sub) == compose(f0,g0)
@test codom(sub) == compose(f,g)
@test subob_dom(sub) == SubOb(A0, A)
@test subob_codom(sub) == SubOb(C0, C)

# Explicit coercions
@test dom(coerce(subA)) == A0
@test codom(coerce(subA)) == A
@test coerce(subob_id(A)) == id(A)
@test compose(coerce(subob_id(A)), f) == f
@test compose(f, coerce(subob_id(B))) == f

# Constructors
@test dom(construct(A)) == I
@test codom(construct(A)) == A
@test dom(construct(f)) == B
@test codom(construct(f)) == A

# Pairs
f, g = Hom(:f, A, B), Hom(:g, A, C)
@test dom(pair(f,g)) == A
@test codom(pair(f,g)) == otimes(B,C)
@test pair(f,g) == compose(mcopy(A), otimes(f,g))
@test dom(pair(A0,f,g)) == A0
@test codom(pair(A0,f,g)) == otimes(B,C)

# Monocl wiring diagram
#######################

A0, A, B0, B = Ob(Monocl, :A0, :A, :B0, :B)
f = Hom(:f, A, B)
g = Hom(:g, B, A)

diagram = to_wiring_diagram(f)
@test boxes(diagram) == [ Box(f) ]
@test input_ports(diagram) == [ A ]
@test output_ports(diagram) == [ B ]

# Coercion
sub = SubOb(A0, A)
diagram = to_wiring_diagram(compose(coerce(sub), f))
@test boxes(diagram) == [ Box(f) ]
@test input_ports(diagram) == [ A0 ]
@test output_ports(diagram) == [ B ]

# Graphviz support.
diagram = to_wiring_diagram(compose(coerce(SubOb(A0,A)), construct(g)))
@test isa(to_graphviz(diagram), Graphviz.Graph)

end
