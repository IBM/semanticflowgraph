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
#write_rdf(STDOUT, stmts)

@test Triple(R("ex","A"), R("rdf","type"), R("monocl","Type")) in stmts
@test Triple(R("ex","A0"), R("rdf","type"), R("monocl","Type")) in stmts
@test Triple(R("ex","A0"), R("monocl","subtype_of"), R("ex","A")) in stmts
@test Triple(R("ex","f0"), R("monocl","subfunction_of"), R("ex","f")) in stmts

@test Triple(R("ex","g"), R("rdf","type"), R("monocl","Function")) in stmts
@test Triple(R("ex","g"), R("monocl","input_port"), R("ex","A")) in stmts
@test Triple(R("ex","g"), R("monocl","output_port"), R("ex","B")) in stmts
@test Triple(R("ex","g"), R("monocl","output_port"), R("ex","C")) in stmts
@test Triple(R("ex","A"), R("monocl","in"), R("ex","g")) in stmts
@test Triple(R("ex","g"), R("monocl","out"), R("ex","B")) in stmts
@test Triple(R("ex","g"), R("monocl","out"), R("ex","C")) in stmts

end
