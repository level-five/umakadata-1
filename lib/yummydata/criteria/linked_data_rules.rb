require 'yummydata/http_helper'
require 'yummydata/error_helper'

module Yummydata
  module Criteria
    module LinkedDataRules

      include Yummydata::HTTPHelper
      include Yummydata::ErrorHelper

      def prepare(uri)
        @client = SPARQL::Client.new(uri, {'read_timeout': 5 * 60}) if @uri == uri && @client == nil
        @uri = uri
      end

      def uri_subject?(uri)
        self.prepare(uri)

        sparql_query = <<-'SPARQL'
SELECT
  *
WHERE {
GRAPH ?g { ?s ?p ?o } .
  filter (!isURI(?s) AND !isBLANK(?s) AND ?g NOT IN (
    <http://www.openlinksw.com/schemas/virtrdf#>
  ))
}
LIMIT 1
SPARQL

        begin
          results = @client.query(sparql_query)
        rescue => e
          set_error(e)
          return false
        end

        self.has_no_count?(results)
      end

      def http_subject?(uri)
        self.prepare(uri)

        sparql_query = <<-'SPARQL'
SELECT
  *
WHERE {
  GRAPH ?g { ?s ?p ?o } .
  filter (!regex(?s, "http://", "i") AND !isBLANK(?s) AND ?g NOT IN (
    <http://www.openlinksw.com/schemas/virtrdf#>
  ))
}
LIMIT 1
SPARQL

        begin
          results = @client.query(sparql_query)
        rescue => e
          set_error(e)
          return false
        end
        self.has_no_count?(results)
      end

      def uri_provides_info?(uri)
        self.prepare(uri)

        uri = self.get_subject_randomly()
        if uri == nil
          return false
        end
        begin
          response = http_get_recursive(URI(uri), {}, 10)
        rescue => e
          set_error("INVALID URI: #{uri}")
          puts "INVALID URI: #{uri}"
          return false
        end

        if !response.is_a?(Net::HTTPSucces)
          set_error(http_response)
        else
          if !response.body.empty?
            return true
          end
          set_error("html body is empty")
        end
        return false
      end

      def get_subject_randomly
        sparql_query = <<-'SPARQL'
SELECT
  ?s
WHERE {
  GRAPH ?g { ?s ?p ?o } .
  filter (isURI(?s) AND ?g NOT IN (
    <http://www.openlinksw.com/schemas/virtrdf#>
  ))
}
LIMIT 1
OFFSET 100
SPARQL
        begin
          results = @client.query(sparql_query)
        rescue => e
          set_error(e)
          return nil
        end
        if results != nil && results[0] != nil
          results[0][:s]
        else
          set_error("sparql query has no result")
          nil
        end
      end

      def contains_links?(uri)
        self.prepare(uri)

        self.contains_same_as?() || self.contains_see_also?()
      end

      def contains_same_as?
        sparql_query = <<-'SPARQL'
PREFIX owl:<http://www.w3.org/2002/07/owl#>
SELECT
  *
WHERE {
  GRAPH ?g { ?s owl:sameAs ?o } .
}
LIMIT 1
SPARQL
        begin
          results = @client.query(sparql_query)
        rescue => e
          set_error(e)
          return false
        end

        self.has_count?(results)
      end

      def contains_see_also?
        sparql_query = <<-'SPARQL'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT
  *
WHERE {
  GRAPH ?g { ?s rdfs:seeAlso ?o } .
}
LIMIT 1
SPARQL
        begin
          results = @client.query(sparql_query)
        rescue => e
          set_error(e)
          return false
        end

        self.has_count?(results)
      end

      def has_no_count?(results)
          if results == nil
            set_error("sparql query has no result")
          else
            return true if results.count == 0
            set_error("the count of result is not 0")
          end
          return false
      end

      def has_count?(results)
        if results != nil && results.count > 0
          return true
        end
        set_error("sparql query has no result")
        return false
      end

    end
  end
end
