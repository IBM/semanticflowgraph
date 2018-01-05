module TestOntology
using Base.Test

@testset "JSON" begin
  include("OntologyJSON.jl")
end

@testset "Database" begin
  include("OntologyDBs.jl")
end

end
