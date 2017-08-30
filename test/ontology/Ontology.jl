module TestOntology
using Base.Test

@testset "Ontology" begin
  include("ConceptJSON.jl")
  include("AnnotationJSON.jl")
end

end
