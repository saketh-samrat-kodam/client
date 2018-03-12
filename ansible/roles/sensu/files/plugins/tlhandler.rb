#!/usr/bin/env ruby

require 'json'

event = JSON.parse(STDIN.read, :symbolize_names => true)
status = event[:check][:status]
service = event[:check][:service]
client = event[:client][:name]
%x(echo "idf.tl.#{service}.#{client} #{status} $(date +%s)" | nc graphite.idf.capgeminidigital.com 2003)