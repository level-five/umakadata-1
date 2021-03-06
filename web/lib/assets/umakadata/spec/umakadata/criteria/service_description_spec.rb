require 'spec_helper'

describe 'Umakadata' do
  describe 'Criteria' do
    describe 'ServiceDescription' do

      describe '#service_description' do

        let(:test_class) { Struct.new(:target) { include Umakadata::Criteria::ServiceDescription } }
        let(:target) { test_class.new }

        before do
          @uri = URI('http://example.com')
        end

        def read_file(file_name)
          cwd = File.expand_path('../../../data/umakadata/criteria/service_description', __FILE__)
          File.open(File.join(cwd, file_name)) do |file|
            file.read
          end
        end

        it 'should return service description object when valid response is retrieved of ttl format' do
          valid_ttl = read_file('good_turtle_01.ttl')
          response = double(Net::HTTPResponse)
          allow(target).to receive(:http_get).with(@uri, anything).and_return(response)
          allow(response).to receive(:is_a?).and_return(true)
          allow(response).to receive(:body).and_return(valid_ttl)
          allow(response).to receive(:each_key).and_yield("@prefix rdf").and_yield("@prefix ns1")
          allow(response).to receive(:[]).with("@prefix rdf").and_return("<http://www.w3.org/1999/02/22-rdf-syntax-ns#> .")
          allow(response).to receive(:[]).with("@prefix ns1").and_return("<http://data.allie.dbcls.jp/> .")

          service_description = target.service_description(@uri, 10)

          expect(service_description.type).to eq Umakadata::DataFormat::TURTLE
          expect(service_description.text).to eq valid_ttl
          expect(!service_description.response_header.empty?).to be true
        end

        it 'should return service description object when response is retrieved of xml format' do
          valid_xml = read_file('good_xml_01.xml')
          response = double(Net::HTTPResponse)
          allow(target).to receive(:http_get).with(@uri, anything).and_return(response)
          allow(response).to receive(:is_a?).and_return(true)
          allow(response).to receive(:body).and_return(valid_xml)
          allow(response).to receive(:each_key).and_yield("@prefix rdf").and_yield("@prefix ns1")
          allow(response).to receive(:[]).with("@prefix rdf").and_return("<http://www.w3.org/1999/02/22-rdf-syntax-ns#> .")
          allow(response).to receive(:[]).with("@prefix ns1").and_return("<http://data.allie.dbcls.jp/> .")

          service_description = target.service_description(@uri, 10)

          expect(service_description.type).to eq Umakadata::DataFormat::RDFXML
          expect(service_description.text).to eq valid_xml
          expect(!service_description.response_header.empty?).to be true
        end

        it 'should return service description object when invalid response is retrieved' do
          invalid_ttl = read_file('bad_turtle_01.ttl')
          response = double(Net::HTTPResponse)
          allow(target).to receive(:http_get).with(@uri, anything).and_return(response)
          allow(response).to receive(:is_a?).and_return(true)
          allow(response).to receive(:body).and_return(invalid_ttl)

          service_description = target.service_description(@uri, 10)

          expect(service_description.type).to eq Umakadata::DataFormat::UNKNOWN
          expect(service_description.text).to eq nil
          expect(service_description.response_header).to eq ''
        end

        it 'should return nil when an occured client error' do
          response = double(Net::HTTPNotFound)
          allow(target).to receive(:http_get).with(@uri, anything).and_return(response)
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPResponse).and_return(true)

          service_description = target.service_description(@uri, 10)

          expect(service_description).to be_nil
        end

        it 'should return nil when an occured server error' do
          response = double(Net::HTTPInternalServerError)
          allow(target).to receive(:http_get).with(@uri, anything).and_return(response)
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
          allow(response).to receive(:is_a?).with(Net::HTTPResponse).and_return(true)

          service_description = target.service_description(@uri, 10)

          expect(service_description).to be_nil
        end

      end
    end
  end
end
