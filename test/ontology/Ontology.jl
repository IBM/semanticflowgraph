module TestOntology
using Base.Test

@testset "Ontology" begin
  include("OntologyJSON.jl")
  include("OntologyDBs.jl")
end

end
