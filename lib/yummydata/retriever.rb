require "yummydata/criteria/liveness"
require "yummydata/criteria/service_description"
require "yummydata/criteria/linked_data_rules"
require "yummydata/criteria/void"
require "yummydata/criteria/execution_time"
require "yummydata/criteria/cool_uri"
require "yummydata/criteria/content_negotiation"
require "yummydata/criteria/metadata"
require "yummydata/criteria/last_update"

module Yummydata
  class Retriever

    def initialize(uri)
      @uri = URI(uri)
    end

    include Yummydata::Criteria::Liveness
    def alive?(time_out = 30)
      super(@uri, time_out)
    end

    include Yummydata::Criteria::ServiceDescription
    def service_description(time_out = 30)
      super(@uri, time_out)
    end

    include Yummydata::Criteria::LinkedDataRules
    def uri_subject?
      super(@uri)
    end
    def http_subject?
      super(@uri)
    end
    def uri_provides_info?
      super(@uri)
    end
    def contains_links?
      super(@uri)
    end

    include Yummydata::Criteria::VoID
    def well_known_uri
      super(@uri)
    end
    def void_on_well_known_uri(time_out = 30)
      super(@uri, time_out)
    end

    include Yummydata::Criteria::ExecutionTime
    def execution_time
      super(@uri)
    end

    include Yummydata::Criteria::CoolURI
    def cool_uri_rate
      super(@uri)
    end

    include Yummydata::Criteria::ContentNegotiation
    def check_content_negotiation(content_type)
      super(@uri, content_type)
    end

    include Yummydata::Criteria::Metadata
    def metadata
      super(@uri)
    end

    include Yummydata::Criteria::LastUpdate
    def last_modified
      super
    end

    def count_first_last
      count = count_statements
      return {count: nil, first: nil, last: nil } if count.nil?

      first = first_statement
      last = last_statement(count)
      return {count: count, first: first, last: last}
    end

  end
end
