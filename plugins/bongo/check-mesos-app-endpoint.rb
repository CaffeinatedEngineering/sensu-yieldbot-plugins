#! /usr/bin/env ruby
#
# check-bongo-endpoint.rb
#
# DESCRIPTION:
#
#
# OUTPUT:
#   JSON
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015,Yieldbot <devops@yieldbot.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'json'
require 'rest-client'

#
# Get a set of metrics from an app running in Mesos
#
class MesosAppEndpointCheck < Sensu::Plugin::Check::CLI
  option :server,
         description: 'The consul dns name of the mesos server',
         short: '-s SERVER',
         long: '--server SERVER'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'The port used to query mesos'

  option :app,
         short: '-a APP',
         long: '--app APP',
         description: 'The name of the app to get metrics from'

  # Acquire the slave that a particular app is running on
  #
  def acquire_app_slave
    # consul dns should always be used
    server = config[:server] || 'us-east-1-perpetuum.mesos-marathon.service.consul'
    # the default port is the one supplied by consul
    port   = config[:port] || '443'
    app    = config[:app]

    # break out if the client fails to connect to the mesos master
    begin
      r = RestClient::Resource.new("https://#{server}:#{port}/v2/apps/#{app}", timeout: 10, verify_ssl: false).get
    rescue Errno::ECONNREFUSED, RestClient::ResourceNotFound, SocketError
      critical "#{server} connection was refused"
    rescue RestClient::RequestTimeout
      critical "#{server} connection timed out"
    end
    JSON.parse(r)['app']['tasks'][0]['host']
  end

  def json_valid?(str)
    JSON.parse(str)
    return true
  rescue JSON::ParserError
    return false
  end

  def run
    current_slave = acquire_app_slave
    out = `curl -s -k http://#{current_slave}:31550/v1/kafka/metrics`
    critical unless json_valid?(out)
    ok
  end
end
