#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'openssl'

authUrl = URI.parse("https://identity.api.rackspacecloud.com")
http = Net::HTTP.new(authUrl.host, authUrl.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
request = Net::HTTP::Post::new("/v2.0/tokens")
request.add_field("Content-Type", "application/json")
request.body = '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"gorsti", "apiKey":"ed22af5586783fddfdcbf212923e2a15"}}}'
response = http.request(request)
json = JSON.parse(response.body, :symbolize_names => true)

auth = JSON.parse(response.body, :symbolize_names => true)
authKey = auth[:access][:token][:id]
filename= "/var/log/sensu/node_count.txt"
File.open(filename, 'a') do |file|
        file.puts(authKey)
end

nodesUrl = URI.parse("https://lon.servers.api.rackspacecloud.com")
http = Net::HTTP.new(nodesUrl.host, nodesUrl.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
request = Net::HTTP::Get::new("/v2/10032568/servers/detail")
request.add_field("X-Auth-Token", authKey)
response = http.request(request)


# Debugging purposes
nodes = JSON.parse(response.body, :symbolize_names => true)
filename= "/var/log/sensu/node_count.txt"
File.open(filename, 'a') do |file|
        file.puts(nodes[:servers].length)
end

date = %x(date +%s)
puts "idf.infra.node.count #{nodes[:servers].length} #{date}"
exit 0
