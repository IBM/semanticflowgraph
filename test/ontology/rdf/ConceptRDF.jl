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

module TestConceptRDF
using Test

using Serd
using Serd.RDF: Triple, Resource
using Catlab

using SemanticFlowGraphs

const R = Resource

@present TestPres(Monocl) begin 
  A::Ob
  B::Ob
  C::Ob
  
  A0::Ob
  B0::Ob
  ::SubOb(A0,A)
  ::SubOb(B0,B)
  
  f::Hom(A,B)
  g::Hom(A,otimes(B,C))
  
  f0::Hom(A0,B0)
  ::SubHom(f0,f,SubOb(A0,A),SubOb(B0,B))
end

prefix = RDF.Prefix("ex", "http://www.example.org/#")
stmts = presentation_to_rdf(TestPres, prefix)
#write_rdf(stdout, stmts)

@test Triple(R("ex","A"), R("rdf","type"), R("monocl","TypeConcept")) in stmts
@test Triple(R("ex","A0"), R("rdf","type"), R("monocl","TypeConcept")) in stmts
@test Triple(R("ex","A0"), R("monocl","subtypeOf"), R("ex","A")) in stmts
@test Triple(R("ex","f0"), R("monocl","subfunctionOf"), R("ex","f")) in stmts

@test Triple(R("ex","g"), R("rdf","type"), R("monocl","FunctionConcept")) in stmts
@test Triple(R("ex","g-input1"), R("rdf","type"), R("list","OWLList")) in stmts
@test Triple(R("ex","g-input1"), R("list","hasContent"), R("ex","A")) in stmts
@test Triple(R("ex","g-output1"), R("list","hasContent"), R("ex","B")) in stmts
@test Triple(R("ex","g-output1"), R("list","hasNext"), R("ex","g-output2")) in stmts
@test Triple(R("ex","g-output2"), R("list","hasContent"), R("ex","C")) in stmts

end
