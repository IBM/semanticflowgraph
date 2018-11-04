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

module ConceptRDF
export presentation_to_rdf, generator_rdf_node

using Serd
using Catlab

using ...Doctrine, ...Ontology
using ..OntologyRDF: rdf_list

const R = RDF.Resource

# RDF
#####

""" Convert concepts in Monocl ontology to RDF graph.
"""
function presentation_to_rdf(pres::Presentation, prefix::RDF.Prefix;
                             extra_rdf::Union{Function,Nothing}=nothing,
                             wiring_rdf::Bool=true)
  stmts = RDF.Statement[
    RDF.Prefix("rdf"),
    RDF.Prefix("rdfs"),
    RDF.Prefix("monocl", "https://www.datascienceontology.org/ns/monocl/"),
    prefix
  ]
  for expr in generators(pres)
    append!(stmts, expr_to_rdf(expr, prefix))
    if wiring_rdf && expr isa Monocl.Hom
      append!(stmts, hom_generator_to_wiring_rdf(expr, prefix))
    end
    if extra_rdf != nothing && first(expr) != nothing
      append!(stmts, extra_rdf(expr, generator_rdf_node(expr, prefix)))
    end
  end
  stmts
end

""" Generate RDF for object generator.
"""
function expr_to_rdf(ob::Monocl.Ob{:generator}, prefix::RDF.Prefix)
  # XXX: Objects are not really RDFS Classes but we abuse classes for
  # transitivity inference.
  node = generator_rdf_node(ob, prefix)
  [ RDF.Triple(node, R("rdf","type"), R("monocl","Type")),
    RDF.Triple(node, R("rdf","type"), R("rdfs","Class")) ]
end

""" Generate RDF for subobject relation.
"""
function expr_to_rdf(sub::Monocl.SubOb, prefix::RDF.Prefix)
  dom_node = generator_rdf_node(dom(sub), prefix)
  codom_node = generator_rdf_node(codom(sub), prefix)
  [ RDF.Triple(dom_node, R("monocl","subtype_of"), codom_node),
    RDF.Triple(dom_node, R("rdfs","subClassOf"), codom_node) ]
end

""" Generate RDF for morphism generator.

The domain and codomain objects are represented as RDF Lists.
"""
function expr_to_rdf(hom::Monocl.Hom{:generator}, prefix::RDF.Prefix)
  # XXX: Morphisms are not really RDF Properties but we abuse properties for
  # transitivity inference.
  node = generator_rdf_node(hom, prefix)
  dom_nodes = [ generator_rdf_node(ob, prefix) for ob in collect(dom(hom)) ]
  codom_nodes = [ generator_rdf_node(ob, prefix) for ob in collect(codom(hom)) ]
  dom_node, dom_stmts = rdf_list(dom_nodes, "$(node.name)_input")
  codom_node, codom_stmts = rdf_list(codom_nodes, "$(node.name)_output")
  stmts = RDF.Statement[
    RDF.Triple(node, R("rdf","type"), R("monocl","Function")),
    RDF.Triple(node, R("rdf","type"), R("rdf","Property")),
    RDF.Triple(node, R("monocl","inputs"), dom_node),
    RDF.Triple(node, R("monocl","outputs"), codom_node),
  ]
  append!(stmts, dom_stmts)
  append!(stmts, codom_stmts)
  stmts
end

""" Generate RDF for submorphism relation.
"""
function expr_to_rdf(sub::Monocl.SubHom, prefix::RDF.Prefix)
  dom_node = generator_rdf_node(dom(sub), prefix)
  codom_node = generator_rdf_node(codom(sub), prefix)
  [ RDF.Triple(dom_node, R("monocl","subfunction_of"), codom_node),
    RDF.Triple(dom_node, R("rdfs","subPropertyOf"), codom_node) ]
end

""" Generate RDF for morphism generator in wiring diagram style.

Cf. `wiring_diagram_to_rdf` in `WiringRDF` module.
"""
function hom_generator_to_wiring_rdf(hom::Monocl.Hom{:generator}, prefix::RDF.Prefix)
  node = generator_rdf_node(hom, prefix)
  stmts = RDF.Statement[]
  for (i, dom_ob) in enumerate(collect(dom(hom)))
    port_node = generator_rdf_node(dom_ob, prefix)
    append!(stmts, [
      RDF.Triple(node, R("monocl","input_port"), port_node),
      RDF.Triple(node, R("monocl","input_port_$i"), port_node),
    ])
  end
  for (i, codom_ob) in enumerate(collect(codom(hom)))
    port_node = generator_rdf_node(codom_ob, prefix)
    append!(stmts, [
      RDF.Triple(node, R("monocl","output_port"), port_node),
      RDF.Triple(node, R("monocl","output_port_$i"), port_node),
    ])
  end
  stmts
end

""" Create RDF node for generator expression.
"""
function generator_rdf_node(expr::GATExpr{:generator}, prefix::RDF.Prefix)
  @assert first(expr) != nothing
  R(prefix.name, string(first(expr)))
end

end
