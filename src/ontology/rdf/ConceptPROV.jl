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

module ConceptPROV
export presentation_to_prov

using Serd
using Catlab

using ...Doctrine, ...Ontology
using ..ConceptRDF

const R = RDF.Resource


""" Convert concepts into hierarchy of PROV-O classes.

Type concepts are not really OWL classes and function concepts are not even
close to OWL classes (nor are they particularly close to OWL properties).
However, for the sake of Semantic Web interoperability, we encode type concepts
as a hierarchy of classes below PROV's Entity and function concepts as a
hierarchy of classes below PROV's Activity.

In the primary export function (`presentation_to_rdf`), concepts are represented
as individuals, not classes, which is necessary because they have properties.
Thus, when used in conjunction with this function, concepts are simultaneously
classes and individuals. This is prohibited in OWL 1, but permitted in OWL 2 DL,
where is it called "punning".

References:
- https://www.w3.org/TR/owl2-new-features/#F12:_Punning
- https://www.w3.org/TR/prov-o/
"""
function presentation_to_prov(pres::Presentation, prefix::RDF.Prefix)
  stmts = RDF.Statement[
    RDF.Prefix("rdf"), RDF.Prefix("rdfs"), RDF.Prefix("owl"),
    RDF.Prefix("prov"),
    RDF.Prefix("monocl", "https://www.datascienceontology.org/ns/monocl/"),
    prefix
  ]

  # Create mapping from concept node to all its super concept nodes.
  super_map = Dict{RDF.Node,Vector{RDF.Node}}()
  for sub in [generators(pres, Monocl.SubOb); generators(pres, Monocl.SubHom)]
    push!(get!(super_map, generator_rdf_node(dom(sub), prefix), RDF.Node[]),
          generator_rdf_node(codom(sub), prefix))
  end

  # Generate RDF triples.
  for gen in [generators(pres, Monocl.Ob); generators(pres, Monocl.Hom)]
    node = generator_rdf_node(gen, prefix)
    super_nodes = get(super_map, node) do
      [ gen isa Monocl.Ob ? R("prov","Entity") : R("prov","Activity") ]
    end
    push!(stmts, RDF.Triple(node, R("rdf","type"), R("owl","Class")))
    for super_node in super_nodes
      push!(stmts, RDF.Triple(node, R("rdfs","subClassOf"), super_node))
    end
  end
  stmts
end

end
