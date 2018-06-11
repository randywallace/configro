require "pp"
RSpec.describe Configruous do

  describe 'when included' do
    it "has a version number" do
      expect(Configruous::VERSION).not_to be nil
    end
  end

  describe 'when interacting with the AWS SDK' do

    before(:each) {
      allow(Aws::SSM::Client).to receive(:new).and_return( Aws::SSM::Client.new(stub_responses: true) )
    }

    let(:configruous_client) { Configruous::SSMClient.instance.client }

    describe '#new' do
      it "loads the SSM Client" do
        expect(configruous_client).not_to be nil
      end
    end

    describe '#get_parameter' do
      it "fails to execute when passed no options" do
        expect{configruous_client.get_parameter}.to raise_error(ArgumentError)
      end

      it "throws when passed unknown arg" do
        expect{configruous_client.get_parameter(name: 'something', weird_param: 100)}.to raise_error(ArgumentError)
      end

      it "gets a parameter" do
        response = build(:ssm_get_parameter_response)
        configruous_client.stub_responses(:get_parameter, response)
        expect(configruous_client.get_parameter(name: 'foobar')).to eql(response)
      end
    end

    describe "#get_parameters_by_path" do
      it "fails to execute when passed no options" do
        expect{configruous_client.get_parameters_by_path}.to raise_error(ArgumentError)
      end

      it "throws when passed unknown arg" do
        expect{configruous_client.get_parameters_by_path(path: '/config', weird_param: 100)}.to raise_error(ArgumentError)
      end

      it "gets a parameter by path" do
        response = build(:ssm_get_parameter_by_path_response)
        configruous_client.stub_responses(:get_parameters_by_path, response)
        expect(configruous_client.get_parameters_by_path(path: "/config/test")).to eql(response)
      end
    end

    describe "#put_parameter" do
      it "fails to execute when passed no options" do
        expect{configruous_client.put_parameter}.to raise_error(ArgumentError)
      end

      it "throws when passed unknown arg" do
        expect{configruous_client.put_parameter(name: 'something', value: 'string', weird_param: 100)}.to raise_error(ArgumentError)
      end

      it "puts a parameter" do
        response = build(:ssm_put_parameter_response)
        configruous_client.stub_responses(:put_parameter, response)
        expect(configruous_client.put_parameter(name: "bear", value: "37", type: "String")).to eql(response)
      end
    end
  end

  describe 'RestoreFileFromSSM' do
    before(:each) {
      allow(Aws::SSM::Client).to receive(:new).and_return( Aws::SSM::Client.new(stub_responses: true) )
    }

    let(:configruous_client) { Configruous::SSMClient.instance.client }

    describe "#to_params" do
      before(:each) {
        response = build(:ssm_get_parameter_by_path_response, :yaml)
        configruous_client.stub_responses(:get_parameters_by_path, response)
      }

      it "returns a hash successfully" do
        expect{Configruous::RestoreFileFromSSM.new('environ', 'file.ext').to_params}.to_not raise_error
      end

      it "returns an array of hashes" do
        expect(Configruous::RestoreFileFromSSM.new('environ', 'file.ext').to_params).to be_instance_of(Array)
      end
    end

    describe "#to_filetype" do
      before(:each) {
        response = build(:ssm_get_parameter_by_path_response, trait, number_of_parameters: number_of_parameters, filename: filename, environment: environment)
        configruous_client.stub_responses(:get_parameters_by_path, response)
      }

      let (:environment) { 'production' }

      describe "yaml file" do
        let(:filename) { 'something.yaml' }
        let(:trait) { :yaml }
        let(:number_of_parameters) { 1 }

        it "prints the resulting configuration file without issue" do
          expect{Configruous::RestoreFileFromSSM.new(environment, filename).to_filetype}.to_not raise_error
          puts Configruous::RestoreFileFromSSM.new(environment, filename).to_filetype.to_yaml
        end
      end

      describe "properties file" do
        let(:filename) { 'something.properties' }
        let(:trait) { :properties }
        let(:number_of_parameters) { 10 }

        it "prints the resulting configuration file without issue" do
          expect{Configruous::RestoreFileFromSSM.new(environment, filename).to_filetype}.to_not raise_error
          puts Configruous::RestoreFileFromSSM.new(environment, filename).to_filetype.join("\n")
        end
      end

      describe "unsupported file" do
        let(:filename) { 'something.ext' }
        let(:trait) { :properties }
        let(:number_of_parameters) { 10 }

        it "prints the resulting configuration file without issue" do
          expect{Configruous::RestoreFileFromSSM.new(environment, filename).to_filetype}.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe 'when leveraging FactoryBot' do
    it 'returns a stringified hash factory' do
      expect(build(:static_stringified_hash, :allows_arrays)).to eql({"name"=>"Sebastian", "an_array"=>["white", "orange"]})
    end

    it 'returns a stringified hash factory with configuration change' do
      expect(build(:static_stringified_hash, name: "Joseph")["name"]).to eql("Joseph")
    end

    it 'handles associated factories as hashes' do
      expect(build(:basic_yaml_configuration)).to eql(
        {"some_snake_case_setting"=>"bar",
         "someCamelCaseSetting"=>"foo",
         "a_number"=>45,
         "a_float"=>3.14,
         "a_string"=>"foobar",
         "some_sub_config"=>{"name"=>"Joseph", "an_array"=>["white", "orange"]},
         "some_other_sub_config"=>{"name"=>"Jessica", "an_array"=>["white", "orange"]},
         "array_with_hash"=>{"name"=>"Sebastian", "an_array"=>[{"keyone"=>10},{ "keytwo"=>11}]}
        }
      )
    end
  end

  describe 'when trying to use the base loader directly' do
    describe '#new' do
      it 'throws when initialized directly' do
        expect{Configruous::BaseLoader.new}.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples "a Loader Object" do
    before(:each) {
      allow(mockclass).to receive(mockloadmethod).with(filename).and_return basic_configuration
    }

    describe '#new' do
      it 'loads the stub' do
        expect(client.raw_data).to eql(raw_data_response)
      end

      it 'sets the environment when given' do
        expect(client_with_env.environment).to eql('test')
      end

      it 'converts the data to configurations' do
        expect{client.data}.not_to raise_error
      end

      it 'bails when a bad key name is provided' do
        allow(mockclass).to receive(mockloadmethod).with(filename).and_return basic_configuration_with_error
        expect{client.data}.to raise_error(RuntimeError)
      end
    end

    describe '#store!' do
      it 'successfully stores configs to SSM' do
        expect{client.store!}.not_to raise_error
      end

      it 'stores a new parameter when one does not already exist' do
        Configruous::SSMClient.instance.client.stub_responses(:get_parameter, Aws::SSM::Errors::ParameterNotFound.new('', ''))
        expect{client.store!}.not_to raise_error
      end
    end
    describe '#to_params' do
      it 'successfully creates param hash' do
        expect{client.to_params}.not_to raise_error
        expect(client.to_params).to eql(expected_params)
      end

      it 'properly supports a prefix' do
        expect(client.to_params('test').keys.sample).to start_with('/test')
      end
    end
  end

  describe 'YAMLLoader' do
    it_behaves_like "a Loader Object" do
      let(:mockclass) { YAML }
      let(:mockloadmethod)  { :load_file }
      let(:filename) { 'some_file.yaml' }
      let(:client)   { Configruous::YAMLLoader.new(filename) }
      let(:client_with_env) { Configruous::YAMLLoader.new(filename, environment: 'test') }
      let(:basic_configuration) { build(:basic_yaml_configuration) }
      let(:raw_data_response) { basic_configuration }
      let(:basic_configuration_with_error) { build(:basic_yaml_configuration, "a-parameter_name.&&.that_is_not_allowed".to_sym => 'data') }
      let(:expected_params) {
          {"/config/testing/prod/some_file.yaml/some_snake_case_setting"=>"bar",
           "/config/testing/prod/some_file.yaml/someCamelCaseSetting"=>"foo",
           "/config/testing/prod/some_file.yaml/a_number"=>45,
           "/config/testing/prod/some_file.yaml/a_float"=>3.14,
           "/config/testing/prod/some_file.yaml/a_string"=>"foobar",
           "/config/testing/prod/some_file.yaml/some_sub_config/name"=>"Joseph",
           "/config/testing/prod/some_file.yaml/some_sub_config/an_array/0"=>"white",
           "/config/testing/prod/some_file.yaml/some_sub_config/an_array/1"=>"orange",
           "/config/testing/prod/some_file.yaml/some_other_sub_config/name"=>"Jessica",
           "/config/testing/prod/some_file.yaml/some_other_sub_config/an_array/0"=>"white",
           "/config/testing/prod/some_file.yaml/some_other_sub_config/an_array/1"=>"orange",
           "/config/testing/prod/some_file.yaml/array_with_hash/name"=>"Sebastian",
           "/config/testing/prod/some_file.yaml/array_with_hash/an_array/0/keyone"=>10,
           "/config/testing/prod/some_file.yaml/array_with_hash/an_array/1/keytwo"=>11
          }
      }
    end
  end

  describe 'PropertyLoader' do
    it_behaves_like "a Loader Object" do
      let(:mockclass) { IniFile }
      let(:mockloadmethod) { :load }
      let(:filename) { 'some_file.properties' }
      let(:client)   { Configruous::PropertyLoader.new(filename) }
      let(:client_with_env) { Configruous::PropertyLoader.new(filename, environment: 'test') }
      let(:basic_configuration) { build(:basic_property_configuration) }
      let(:raw_data_response) { basic_configuration["global"] }
      let(:basic_configuration_with_error) { build(:bad_property_configuration) }
      let(:expected_params) { {"/config/testing/prod/some_file.properties/name"=>"Sebastian", "/config/testing/prod/some_file.properties/family"=>"Wilson"} }
    end
  end

  describe 'FileFactory' do
    describe '#load' do
      before(:each) {
        allow(YAML).to receive(:load_file).with('some_file.yaml').and_return build(:basic_yaml_configuration)
        allow(IniFile).to receive(:load).with('some_file.properties').and_return build(:basic_property_configuration)
      }

      it 'returns an instance of YAMLLoader when presented with a .yaml file' do
        expect(Configruous::FileFactory.load('some_file.yaml')).to be_instance_of(Configruous::YAMLLoader)
      end

      it 'returns an instance of PropertyLoader when presented with a .properties file' do
        expect(Configruous::FileFactory.load('some_file.properties')).to be_instance_of(Configruous::PropertyLoader)
      end

      it 'throws an ArgumentError when presented with an unsupported file type' do
        expect{Configruous::FileFactory.load('some_unsupported.file')}.to raise_error(ArgumentError)
      end
    end
  end

  describe 'Helpers' do
    describe '#deep_merge' do
      it 'merges two hashes successfully' do
        expect{Configruous::Helpers.deep_merge({elem: 'test'}, {elem2: 'test2'})}.not_to raise_error
      end

      it 'does a single level merge correctly' do
        expect(Configruous::Helpers.deep_merge({elem: 'test'}, {elem2: 'test2'})).to eql({elem: 'test', elem2: 'test2'})
      end

      it 'does a nested merge correctly' do
        expect(Configruous::Helpers.deep_merge({elem: {nested: 's'}}, {elem: {nested2: 't'}})).to eql({elem: {nested: 's', nested2: 't'}})
      end

      it 'can merge arrays' do
        expect(Configruous::Helpers.deep_merge({elem: [ 'something' ]}, {elem: [ 'something2' ]})).to eql({elem: ['something', 'something2']})
      end

      it 'will bring in an array object' do
        expect(Configruous::Helpers.deep_merge({elem: ['something']}, {elem2: 'something_else'})).to eql({elem: ['something'], elem2: 'something_else'})
      end
    end
  end
end

