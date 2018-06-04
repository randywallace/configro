FactoryBot.define do
  factory :static_stringified_hash, class:Hash do
    name "Sebastian"
    an_array ["white", "orange"]
    initialize_with { attributes.stringify_keys }
  end

  factory :basic_yaml_configuration, class:Hash do
    some_snake_case_setting "bar"
    someCamelCaseSetting "foo"
    a_number 45
    a_float 3.14
    a_string "foobar"
    association :some_sub_config,       factory: :static_stringified_hash, strategy: :build, name: "Joseph"
    association :some_other_sub_config, factory: :static_stringified_hash, strategy: :build, name: "Jessica"
    association :array_with_hash,       factory: :static_stringified_hash, strategy: :build, an_array: [ { "keyone" => 10 },{ "keytwo" => 11 } ]
    initialize_with { attributes.stringify_keys }
  end

  factory :basic_property_configuration, class:Hash do
    association :global, factory: :static_stringified_hash, strategy: :build, an_array: nil, family: 'Wilson'
    initialize_with { attributes.stringify_keys }
  end

  sequence(:name) { |n| "/config/environ/file.ext/config_name/#{n}" }
  sequence(:value) { |n| "#{n}" }
  sequence(:version) { |n| n }

  factory :basic_ssm_parameter, class:Aws::SSM::Types::Parameter do
    name
    type "String"
    value
    version
    initialize_with { Aws::SSM::Types::Parameter.new(attributes) }
  end

  factory :ssm_get_parameter_response, class:Aws::SSM::Types::GetParameterResult do
    transient do
      name
      type "String"
      value
      version
    end
    parameter do
      build( :basic_ssm_parameter, name: name, type: type, value: value, version: version )
    end
    initialize_with { Aws::SSM::Types::GetParameterResult.new(attributes) }
  end


  factory :ssm_get_parameter_by_path_response, class:Aws::SSM::Types::GetParametersByPathResult do

    initialize_with { Aws::SSM::Types::GetParametersByPathResult.new(attributes) }

    after(:build) do |profile|
      profile.parameters = build_list(:basic_ssm_parameter, 10)
    end
  end

  factory :ssm_put_parameter_response, class:Aws::SSM::Types::PutParameterResult do
    version 2
    initialize_with { Aws::SSM::Types::PutParameterResult.new(attributes) }
  end
end

# Aws::SSM::Types::GetParameterRequest
# {
#   name: "PSParameterName", # required
#   with_decryption: false,
# }
#
# Aws::SSM::Types::GetParameterResult
# #parameter = Types::Parameter
#
# Aws::SSM::Types::Parameter
#   #name = String
#     The name of the parameter.
#   #type = String
#     The type of parameter.
#     ( String, StringList, SecureString )
#   #value = String
#     The parameter value.
#   #version = Integer
#     The parameter version.
#
# Class: Aws::SSM::Types::GetParametersByPathRequest
# {
#   path: "PSParameterName", # required
#   recursive: false,
#   parameter_filters: [
#     {
#       key: "ParameterStringFilterKey", # required
#       option: "ParameterStringQueryOption",
#       values: ["ParameterStringFilterValue"],
#     },
#   ],
#   with_decryption: false,
#   max_results: 1,
#   next_token: "NextToken",
# }
#
# Aws::SSM::Types::GetParametersByPathResult 
#   #next_token = String
#     The token for the next set of items to return.
#   #parameters = Array<Types::Parameter>
#     A list of parameters found in the specified hierarchy.
#
# Aws::SSM::Types::PutParameterRequest 
# {
#   name: "PSParameterName", # required
#   description: "ParameterDescription",
#   value: "PSParameterValue", # required
#   type: "String", # required, accepts String, StringList, SecureString
#   key_id: "ParameterKeyId",
#   overwrite: false,
#   allowed_pattern: "AllowedPattern",
# }
#
# Aws::SSM::Types::PutParameterResult 
# #version = Integer 
#
