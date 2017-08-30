module TestOntology
using Base.Test

@testset "Ontology" begin
  include("ConceptJSON.jl")
  include("AnnotationJSON.jl")
  include("OntologyDBs.jl")
end

end
