require 'umakadata/sparql_helper'
require 'umakadata/logging/log'

module Umakadata

  module Criteria

    module Liveness
      ##
      # A boolan value whether if the SPARQL endpoint is alive.
      #
      # @param  uri [URI]: the target endpoint
      # @param  args [Hash]:
      # @return [Boolean]
      def alive?(uri, time_out, logger: nil)
        sparql_query = 'SELECT * WHERE {?s ?p ?o} LIMIT 1'

        [:post, :get].each do |method|
          request_log = Umakadata::Logging::Log.new
          logger.push request_log unless logger.nil?
          response = Umakadata::SparqlHelper.query(uri, sparql_query, logger: request_log, options: {method: method})
          unless response.nil?
            request_log.result = "200 HTTP response"
            logger.result = "The endpoint is alive" unless logger.nil?
            return true
          end
          request_log.result = "An error occurred in checking liveness for the endpoint"
        end
        logger.result = "The endpoint is not alive" unless logger.nil?
        false
      end

    end

  end

end
