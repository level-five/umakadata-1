require 'spec_helper'

describe 'Yummydata' do
  describe 'Criteria' do
    describe 'CoolURI' do

      describe '#cool_uri_rate' do

        let(:test_class) { Struct.new(:target) { include Yummydata::Criteria::CoolURI } }
        let(:target) { test_class.new }

        it 'cool_uri_rate_should_be_100' do
          rate = target.cool_uri_rate(URI('http://example.com/item'))
          expect(rate).to eq 100
          expect(target.get_error).to eq nil
        end

        it 'cool_uri_rate_should_be_75_if_host_is_ip' do
          rate = target.cool_uri_rate(URI('http://192.168.1.100/item'))
          expect(rate).to eq 75
          expect(target.get_error).to eq 'Host is IP'
        end

        it 'cool_uri_rate_should_be_75_if_port_is_specified' do
          rate = target.cool_uri_rate(URI('http://example.com:8080/item'))
          expect(rate).to eq 75
          expect(target.get_error).to eq 'Port is specified'
        end

        it 'cool_uri_rate_should_be_100_even_if_uri_contains_capital_character' do
          rate = target.cool_uri_rate(URI('http://example.com/Item'))
          expect(rate).to eq 100
          expect(target.get_error).to eq nil
        end

        it 'cool_uri_rate_should_be_75_if_url_query_is_specified' do
          rate = target.cool_uri_rate(URI('http://example.com/item?id=10'))
          expect(rate).to eq 75
          expect(target.get_error).to eq 'URL query is specified'
        end

        it 'cool_uri_rate_should_be_75_if_uri_is_logner_than_30' do
          rate = target.cool_uri_rate(URI('http://long-long-long-long-uri.com/item'))
          expect(rate).to eq 75
          expect(target.get_error).to eq 'URI is longer than 30'
        end

        it 'cool_uri_rate_should_be_0_if_all_criteria_are_broken' do
          rate = target.cool_uri_rate(URI('http://192.168.1.100:8080/LongLongLongPath?id=1'))
          expect(rate).to eq 0
          expect(target.get_error).to eq 'Host is IP,Port is specified,URL query is specified,URI is longer than 30'
        end

      end
    end
  end
end
