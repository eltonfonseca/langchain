defmodule LangChain.Chains.DataExtractionChainTest do
  use LangChain.BaseCase

  doctest LangChain.Chains.DataExtractionChain

  alias LangChain.Function
  alias LangChain.FunctionParam
  alias LangChain.Chains.DataExtractionChain
  alias LangChain.ChatModels.ChatOpenAI

  describe "build_extract_function/1" do
    test "parameters_schema is set correctly" do
      property_config =
        [
          FunctionParam.new!(%{name: "person_name", type: :string}),
          FunctionParam.new!(%{name: "person_age", type: :number}),
          FunctionParam.new!(%{name: "person_hair_color", type: :string}),
          FunctionParam.new!(%{name: "dog_name", type: :string}),
          FunctionParam.new!(%{name: "dog_breed", type: :string})
        ]
        |> FunctionParam.to_parameters_schema()

      %Function{} = function = DataExtractionChain.build_extract_function(property_config)

      # the full combined JSONSchema structure for function arguments
      assert function.parameters_schema == %{
               type: "object",
               properties: %{
                 info: %{
                   type: "array",
                   items: %{
                     "type" => "object",
                     "properties" => %{
                       "dog_breed" => %{"type" => "string"},
                       "dog_name" => %{"type" => "string"},
                       "person_age" => %{"type" => "number"},
                       "person_hair_color" => %{"type" => "string"},
                       "person_name" => %{"type" => "string"}
                     },
                     "required" => []
                   }
                 }
               },
               required: ["info"]
             }
    end
  end

  # Extraction - https://js.langchain.com/docs/modules/chains/openai_functions/extraction
  @tag :live_call
  test "data extraction chain" do
    # JSONSchema definition
    schema_parameters =
      [
        FunctionParam.new!(%{name: "person_name", type: :string}),
        FunctionParam.new!(%{name: "person_age", type: :number}),
        FunctionParam.new!(%{name: "person_hair_color", type: :string}),
        FunctionParam.new!(%{name: "dog_name", type: :string}),
        FunctionParam.new!(%{name: "dog_breed", type: :string})
      ]
      |> FunctionParam.to_parameters_schema()

    # Model setup - specify the model and seed
    {:ok, chat} = ChatOpenAI.new(%{model: "gpt-4", temperature: 0, seed: 0})

    # run the chain, chain.run(prompt to extract data from)
    data_prompt =
      "Alex is 5 feet tall. Claudia is 4 feet taller than Alex and jumps higher than him.
       Claudia is a brunette and Alex is blonde. Alex's dog Frosty is a labrador and likes to play hide and seek."

    {:ok, result} =
      DataExtractionChain.run(chat, schema_parameters, data_prompt, verbose: true)

    assert result == [
             %{
               "dog_breed" => "labrador",
               "dog_name" => "Frosty",
               "person_age" => nil,
               "person_hair_color" => "blonde",
               "person_name" => "Alex"
             },
             %{
               "dog_breed" => nil,
               "dog_name" => nil,
               "person_age" => nil,
               "person_hair_color" => "brunette",
               "person_name" => "Claudia"
             }
           ]
  end
end
