require 'net/http'
require 'umakadata/logging/http_log'

module Umakadata

  module HTTPHelper

    def http_get(uri, args = {})
      args = {
        :time_out => 10
      }.merge(args)

      uri = URI.parse(uri.to_s) unless uri.is_a?(URI)

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = args[:time_out]

      path = uri.path.empty? ? '/' : uri.path
      path += '?' + uri.query unless uri.query.nil?
      request = Net::HTTP::Get.new(path, args[:headers])

      http_log = Umakadata::Logging::HttpLog.new(uri, request)

      execute_request(http, request, http_log, args)
    end

    def http_post(uri, form_data, args = {})
      args = {
        :time_out => 10
      }.merge(args)

      uri = URI.parse(uri.to_s) unless uri.is_a?(URI)

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = args[:time_out]

      request = Net::HTTP::Post.new(uri.path.empty? ? '/' : uri.path, args[:headers])
      request.set_form_data(form_data, ';')

      http_log = Umakadata::Logging::HttpLog.new(uri, request)

      execute_request(http, request, http_log, args)
    end

    def execute_request(http, request, http_log, args = {})
      begin
        response = http_log.response = http.start { |h|
          h.request(request)
        }
      rescue => e
        http_log.error = e
      end

      # append a log object to log container
      log = args[:logger]
      log.push http_log unless log.nil?

      response
    end

    def http_get_recursive(uri, args = {}, limit = 10)
      raise RuntimeError, 'HTTP redirect too deep' if limit == 0

      response = http_get(uri, args)

      return http_get_recursive(URI(response['location']), args, limit - 1) if response.is_a? Net::HTTPRedirection
      return response
    end

  end

end
