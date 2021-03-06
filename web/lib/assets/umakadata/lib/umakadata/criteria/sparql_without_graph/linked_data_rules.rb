require 'umakadata/http_helper'
require 'umakadata/sparql_helper'
require 'umakadata/logging/log'

module Umakadata
  module Criteria
    module SPARQLWithoutGraph
      module LinkedDataRules

        include Umakadata::HTTPHelper

        REGEXP = /<title>(.*)<\/title>/

        def prepare(uri)
          @client = SPARQL::Client.new(uri, {'read_timeout': 5 * 60}) if @uri == uri && @client == nil
          @uri = uri
        end

        def is_http_subject?(uri, offset, logger: nil)
          sparql_query = <<-"SPARQL"
SELECT
  ?s
WHERE {
  { ?s ?p ?o } .
  FILTER (!isBLANK(?s))
}
OFFSET #{offset}
LIMIT 1
SPARQL

          is_http = false
          [:post, :get].each do |method|
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
            if !results.is_a?(RDF::Query::Solutions) or results[0].nil?
              log.result = "Failed to retrieve subject of #{offset}th triples"
              next
            end
            subject = results[0][:s].to_s
            is_http = !(subject =~  URI.regexp(['http', 'https'])).nil?
            log.result = "#{subject} is#{is_http ? "" : " not"} HTTP/HTTPS URI"
            break
          end
          logger.result = "The subject of #{offset}th triple is#{is_http ? "" : " not"} HTTP/HTTPS URI" unless logger.nil?

          return is_http
        end

        NUMBER_OF_SAMPLES = 5
        RATIO_OF_NOT_BLANK_SUBJECT = 0.1

        def http_subject?(uri, number_of_statements, logger: nil)
          random = Random.new
          min = 1
          max = (number_of_statements * RATIO_OF_NOT_BLANK_SUBJECT).to_i
          if min > max
            logger.result = "too small number of statements #{number_of_statements}"
            return false
          end

          range = Range.new(min, max)
          count = 0
          for i in Range.new(1, NUMBER_OF_SAMPLES) do
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            offset = random.rand(range)
            count += 1 if is_http_subject?(uri, offset, logger: log)
          end

          ratio = (count.to_f / NUMBER_OF_SAMPLES * 100).to_i
          logger.result = "#{ratio}% subjects in the endpoint are HTTP/HTTPS URI"
          return ratio > 60
        end

        def uri_provides_info?(uri, prefixes, logger: nil)
          uri = self.get_subject(uri, prefixes, logger: logger)
          if uri == nil
            logger.result = 'The endpoint does not have information about URI' unless logger.nil?
            return false
          end

          begin
            response = http_head_recursive(URI(uri), {}, logger: logger)
          rescue => e
            logger.result = 'An error occurred in getting uri recursively' unless logger.nil?
            return false
          end

          if !response.is_a?(Net::HTTPSuccess)
            logger.result = 'HTTP response is not 2xx Success' unless logger.nil?
            return false
          end

          if response.content_length.nil?
            logger.result = "#{uri} does not return any data" unless logger.nil?
            return false
          end

          logger.result = "#{uri} provides useful information" unless logger.nil?
          true
        end

        def get_subject(uri, prefixes, logger: nil)
          return get_subject_with_filter_condition(uri, prefixes, logger: logger) if prefixes.count <= 30
          get_subject_in_10000_triples(uri, prefixes, logger: logger)
        end

        def get_subject_with_filter_condition(uri, prefixes, logger: nil)
          conditions = prefixes.map{|prefix| "regex(STR(?s), '^#{prefix}', 'i')"}.join(' || ')
          sparql_query = <<-"SPARQL"
SELECT
  ?s
WHERE {
  { ?s ?p ?o } .
  filter (#{conditions})
}
LIMIT 1
SPARQL

          [:post, :get].each do |method|
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
            if results != nil
              if results[0] != nil
                log.result = "#{results[0][:s]} subject is found"
                return results[0][:s]
              else
                log.result = 'URI is not found'
              end
            else
              log.result = 'SPARQL query result could not be read in RDF format'
            end
          end
          nil
        end

        def get_subject_in_10000_triples(uri, prefixes, logger: nil)
          sparql_query = <<-'SPARQL'
SELECT
  ?s
WHERE {
  { ?s ?p ?o } .
}
LIMIT 10000
SPARQL

          [:post, :get].each do |method|
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
            if results != nil
              result = search_subject_from_prefixes(prefixes, results)
              unless result.nil?
                log.result = "#{result} subject is found"
                return result
              end
              log.result = 'URI is not found'
            else
              log.result = 'SPARQL query result could not be read in RDF format'
            end
          end
          nil
        end

        def contains_links?(uri, prefixes, logger: nil)
          same_as_log = Umakadata::Logging::Log.new
          logger.push same_as_log unless logger.nil?
          same_as = self.contains_same_as?(uri, prefixes, logger: same_as_log)
          if same_as
            logger.result = "#{uri} includes links to other URIs" unless logger.nil?
            return true
          end

          contains_see_also_log = Umakadata::Logging::Log.new
          logger.push contains_see_also_log unless logger.nil?
          see_also = self.contains_see_also?(uri, prefixes, logger: contains_see_also_log)
          if see_also
            logger.result = "#{uri} includes links to other URIs" unless logger.nil?
            return true
          end
          logger.result = "#{uri} does not include links to other URIs" unless logger.nil?
          false
        end

        def contains_same_as?(uri, prefixes, logger: nil)
          return contains_same_as_with_filter_condition(uri, prefixes, logger: logger) if prefixes.count <= 30
          contains_same_as_in_10000_triples(uri, prefixes, logger: logger)
        end

        def contains_same_as_with_filter_condition(uri, prefixes, logger: nil)
          conditions = prefixes.map{|prefix| "regex(STR(?s), '^#{prefix}', 'i')"}.join(' || ')
          sparql_query = <<-"SPARQL"
PREFIX owl:<http://www.w3.org/2002/07/owl#>
SELECT
  *
WHERE {
  { ?s owl:sameAs ?o } .
  filter(#{conditions})
}
LIMIT 1
SPARQL

          [:post, :get].each do |method|
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
            if results != nil && results.count > 0
              log.result = "#{results.count} owl:sameAs statements are found"
              logger.result = "#{uri} has statements which contain owl:sameAs" unless logger.nil?
              return true
            end
            log.result = 'The owl:sameAs statement is not found'
          end
          logger.result = "#{uri} does not have statements which contain owl:sameAs" unless logger.nil?
          false
        end

        def contains_same_as_in_10000_triples(uri, prefixes, logger: nil)
          sparql_query = <<-'SPARQL'
PREFIX owl:<http://www.w3.org/2002/07/owl#>
SELECT
  *
WHERE {
  { ?s owl:sameAs ?o } .
}
LIMIT 10000
SPARQL

          [:post, :get].each do |method|
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
            if results != nil && results.count > 0
              result = search_subject_from_prefixes(prefixes, results)
              unless result.nil?
                log.result = "#{results.count} owl:sameAs statements are found"
                logger.result = "#{uri} has statements which contain owl:sameAs" unless logger.nil?
                return true
              end
            end
            log.result = 'The owl:sameAs statement is not found'
          end
          logger.result = "#{uri} does not have statements which contain owl:sameAs" unless logger.nil?
          false
        end

        def contains_see_also?(uri, prefixes, logger: nil)
          return contains_see_also_with_filter_condition(uri, prefixes, logger: logger) if prefixes.count <= 30
          contains_see_also_in_10000_triples(uri, prefixes, logger: logger)
        end

        def contains_see_also_with_filter_condition(uri, prefixes, logger: nil)
          conditions = prefixes.map{|prefix| "regex(STR(?s), '^#{prefix}', 'i')"}.join(' || ')
          sparql_query = <<-"SPARQL"
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT
  *
WHERE {
  { ?s rdfs:seeAlso ?o } .
  filter(#{conditions})
}
LIMIT 1
SPARQL

          [:post, :get].each do |method|
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
            if results != nil && results.count > 0
              log.result = "#{results.count} rdfs:seeAlso statements are found"
              logger.result = "#{uri} has statements which contain rdfs:seeAlso" unless logger.nil?
              return true
            end
            log.result = 'The rdfs:seeAlso statement is not found'
          end
          logger.result = "#{uri} does not have statements which contain rdfs:seeAlso" unless logger.nil?
          false
        end


        def contains_see_also_in_10000_triples(uri, prefixes, logger: nil)
          sparql_query = <<-'SPARQL'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT
  *
WHERE {
  { ?s rdfs:seeAlso ?o } .
}
LIMIT 10000
SPARQL

          [:post, :get].each do |method|
            log = Umakadata::Logging::Log.new
            logger.push log unless logger.nil?
            results = Umakadata::SparqlHelper.query(uri, sparql_query, logger: log, options: {method: method})
            if results != nil && results.count > 0
              result = search_subject_from_prefixes(prefixes, results)
              unless result.nil?
                log.result = "#{results.count} rdfs:seeAlso statements are found"
                logger.result = "#{uri} has statements which contain rdfs:seeAlso" unless logger.nil?
                return true
              end
            end
            log.result = 'The rdfs:seeAlso statement is not found'
          end
          logger.result = "#{uri} does not have statements which contain rdfs:seeAlso" unless logger.nil?
          false
        end

        def search_subject_from_prefixes(prefixes, results)
          prefix_map = make_prefix_map(prefixes)
          results.each do |result|
            subject = result[:s].to_s
            uri = URI(subject)
            prefix_candidates = prefix_map[uri.host]
            next if prefix_candidates.nil?
            prefix_candidates.each do |prefix|
              return subject if subject.match("^#{prefix}")
            end
          end
          nil
        end

        def make_prefix_map(prefixes)
          map = {}
          prefixes.each do |prefix|
            uri = URI(prefix)
            host = uri.host
            list = map[host] ||= Array.new
            map[host] = list.push prefix
          end
          map
        end

      end
    end
  end
end
