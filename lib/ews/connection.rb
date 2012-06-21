=begin
  This file is part of Viewpoint; the Ruby library for Microsoft Exchange Web Services.

  Copyright © 2011 Dan Wanek <dan.wanek@gmail.com>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
=end
require 'httpclient'

class Viewpoint::EWS::Connection
  include Viewpoint::EWS

  attr_reader :endpoint
  # @param [String] endpoint the URL of the web service.
  #   @example https://<site>/ews/Exchange.asmx
  def initialize(endpoint)
    @log = Logging.logger[self.class.name.to_s.to_sym]
    @httpcli = HTTPClient.new
    # Up the keep-alive so we don't have to do the NTLM dance as often.
    @httpcli.keep_alive_timeout = 60
    @httpcli.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @endpoint = endpoint
  end

  def set_auth(user,pass)
    @httpcli.set_auth(@endpoint.to_s, user, pass)
  end

  # Authenticate to the web service. You don't have to do this because
  # authentication will happen on the first request if you don't do it here.
  # @return [Boolean] true if authentication is successful, false otherwise
  def authenticate
    self.get && true
  end

  # Send a GET to the web service
  # @return [String] If the request is successful (200) it returns the body of
  #   the response.
  def get
    check_response( @httpcli.get(@endpoint) )
  end

  # Send a POST to the web service
  # @return [String] If the request is successful (200) it returns the body of
  #   the response.
  def post(xmldoc)
    headers = {'Content-Type' => 'text/xml'}
    check_response( @httpcli.post(@endpoint, xmldoc, headers) )
  end


  private

  def check_response(resp)
    case resp.status
    when 200
      resp.body
    when 302
      # @todo redirect
      raise "Unhandled HTTP Redirect"
    when 500
      if resp.headers['Content-Type'].include?('xml')
        err_string, err_code = parse_soap_error(resp.body)
        raise "SOAP Error: Message: #{err_string}  Code: #{err_code}"
      else
        raise "Internal Server Error. Message: #{resp.body}"
      end
    else
      raise "HTTP Error Code: #{resp.status}, Msg: #{resp.body}"
    end
  end

  # @param [String] xml to parse the errors from.
  def parse_soap_error(xml)
    ndoc = Nokogiri::XML(xml)
    ns = ndoc.collect_namespaces
    err_string  = ndoc.xpath("//faultstring",ns).text
    err_code    = ndoc.xpath("//faultcode",ns).text
    @log.debug "Internal SOAP error. Message: #{err_string}, Code: #{err_code}"
    [err_string, err_code]
  end

end
