#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'openssl'
require 'erb'

class AlertHandler < Sensu::Handler

  option :username,
         :description => 'The username of the Jira account.',
         :short => '-u USERNAME',
         :long => '--username USERNAME'

  option :password,
         :description => 'The password of the Jira account.',
         :short => '-p PASSWORD',
         :long => '--password PASSWORD'

  option :jirahost,
         :description => 'The host and port of the Jira instance to use.',
         :short => '-h HOST',
         :long => '--host HOST'

  option :project,
         :description => 'The Jira project to create the issue in.',
         :short => '-n PROJECT',
         :long => '--project PROJECT'

  def filter
  end

  def handle
        puts "Alert Handler called."

        unless config[:username] == "disabled" || config[:password] == "disabled"
          numbers = settings["alert"]["numbers"]
          raise 'Please define a valid mobile phone number.' if numbers.nil? || numbers.length == 0

          service = @event['check']['service']
          service = "unknown" if service.nil? || service == ""

		      client = @event['client']['name']
		      client = "unknown" if client.nil? || client == ""

          unless jira_issue_exists service
                issueNumber = create_jira_issue service, client
                alert_users numbers, issueNumber, service, client
          end
        end
  end

  def jira_issue_exists (service)

        puts "Checking for existing issue."
        existingIssue = false
       
        case @event['check']['status']
          when 0
          return true  
    	    when 1
          label = "-rps-warning"
          when 2
          label = "-rps-critical"
        end
      
        urlAsString = 'https://' + config[:jirahost] + '/rest/api/2/search?jql=status="in backlog" AND project="' + config[:project] + '" AND labels="' + config[:project] + label + '"&maxResults=1&validateQuery=true&fields=summary,status,resolution'
        url = URI.parse(URI.escape(urlAsString))
 
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        puts "Request Uri: #{url.request_uri}"
        request = Net::HTTP::Get.new(url.request_uri)
        request.add_field("Content-Type", "application/json")
        request.basic_auth(config[:username], config[:password])

        response = http.request(request)
        if response.code != '200'
                bail 'Error whilst talking to Jira. Status code returned is: ' + response.code
        end

        issue = JSON.parse(response.body, :symbolize_names => true)
        totalIssues = issue[:total]
        puts "Total Issues: #{totalIssues}"
        unless totalIssues == 0
          existingIssue = true
        end
        puts "Jira task exists: #{existingIssue}"
        return existingIssue
  end

  def create_jira_issue (service, client)
        puts "Creating a new issue."
        url = URI.parse('https://' + config[:jirahost] + '/rest/api/2/issue')

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        request = Net::HTTP::Post.new(url.request_uri)
        request.add_field("Content-Type", "application/json")
        request.basic_auth(config[:username], config[:password])
       
 
      case @event['check']['status']
    	when 1
    		summary = "The " + service + " service has reached maximum safe RPS."
    		description = "The number of Requests-per-second (RPS) on the " + client + " client for the " + service + " service has reached the maximum safe threshold. It is  reporting " + event_data + ". Please see the Kibana dashboard for more information at http://162.13.1.141/#/dashboard/file/mule_rps_dashboard.json"
        status = "-rps-warning"
      when 2
        summary = "The " + service + " service has exceeded maximum safe RPS."
    		description = "The number of Requests-per-second (RPS) on the " + client + " client for the " + service + " service has exceeded its maximum threshold. It is  reporting " + event_data + ". Please see the Kibana dashboard for more information at http://162.13.1.141/#/dashboard/file/mule_rps_dashboard.json"
        status = "-rps-critical"
    	end
        
        body = '{"fields": {"project":{"key": "' + config[:project] + '"},"summary": "' + summary + '","description": "' + description + '","issuetype": {"name": "Incident"},"labels": ["' + config[:project] + status + '"]}}'
        request.body = body

        response = http.request(request)
        if response.code != '200' && response.code != '201'
                bail 'Error whilst talking to Jira. Status code returned is: ' + response.code
        end
        jira = JSON.parse(response.body, :symbolize_names => true)
        return jira[:key]
  end

  def alert_users (numbers, jiraIssue, service, client) 
  	for i in 0..numbers.length - 1
  		number = numbers[i]
  		
    	puts "Alerting user on #{number} of Jira issue: #{jiraIssue}"
    	jiraIssueUrl = "https://" + config[:jirahost] + "/browse/" + jiraIssue

    	case @event['check']['status']
    	when 0
      		send_sms(number, "OK - The #{service} service operating normally.")
    	when 1
      		send_sms(number, "WARNING #{service} reporting potential issues with #{client}. Jira raised: #{jiraIssueUrl}")
    	when 2
      		send_sms(number, "CRITICAL #{service} is reporting serious issues with  #{client}. Jira raised: #{jiraIssueUrl}")
    	end		
  	end
  end

  # this logic should be moved out of this class
  def event_data
    message = @event['check']['output']
    "#{message.split[1]} RPS"
  end

  def send_sms(number, content)
    puts "Sending SMS to #{number}"
    content[157..content.length] = '...' if content.length > 160

    encoded_content = ERB::Util::url_encode(content)
    response = Net::HTTP.get_response('api.idf.capgeminidigital.com', "/text/1/message/service/#{number}/#{encoded_content}")

    unless response.class < Net::HTTPSuccess
      puts "Call to SMS API Failed: #{response.code} - #{response.message} - #{response.body}"
    end
  end

  def filter_repeated
    history = @event['check']['history']
    if history.length < 5
      bail 'not enough occurrences: ' + history.to_s
    else
      last_five = history.last(5)
      if last_five.uniq.length != 1 || last_five[0] == 0
        bail 'not enough occurrences in sequence: ' + last_five.to_s
      end
    end
  end
end