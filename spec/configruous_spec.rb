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

  describe 'when loading YAML configurations' do
    let(:filename) { 'some_file.yaml' }
    let(:client)   { Configruous::YAMLLoader.new(filename) }

    before(:each) {
      allow(YAML).to receive(:load_file).with(filename).and_return build(:basic_yaml_configuration)
    }

    describe '#new' do
      it 'loads the yaml stub' do
        expect(client.raw_data).to eql(build(:basic_yaml_configuration))
      end

      it 'converts the data to configurations' do
        expect{client.data}.not_to raise_error
      end

      it 'bails when a bad key name is provided' do
        dta = build(:basic_yaml_configuration, "a-parameter_name.&&.that_is_not_allowed".to_sym => 'data')
        allow(YAML).to receive(:load_file).with(filename).and_return dta
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

  end

  describe 'when loading Propery file configurations' do
    let(:filename) { 'some_file.properties' }
    let(:client)   { Configruous::PropertyLoader.new(filename) }

    before(:each) {
      allow(IniFile).to receive(:load).with(filename).and_return build(:basic_property_configuration)
    }

    describe '#new' do
      it 'loads the ini stub' do
        expect(client.raw_data).to eql(build(:basic_property_configuration)["global"])
      end

      it 'converts the data to configurations' do
        expect{client.data}.not_to raise_error
      end

      it 'bails when a bad key name is provided' do
        dta = build(:bad_property_configuration)
        allow(IniFile).to receive(:load).with(filename).and_return dta
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
  end
end

