require 'okubi/version'
require 'dotenv/load'
require 'require_all'
require 'okapi'
require 'kubeclient'
require 'clamp'
require 'pastel'
require 'tty-spinner'
require 'tty-command'
require 'tty-prompt'
require 'multi_json'
require 'hashugar'
require 'psych'
require 'configatron'
require 'pry-byebug'
require 'erb'
require 'tempfile'
require 'dnsimple'
require 'net/ping'
require 'resolv'
require 'ssl-test'
require 'tilt'
require 'tilt/erb'
require 'open-uri'

require_rel 'okubi/cli/utils'
require 'okubi/cli/operation.rb'
require 'okubi/cli/cli.rb'

# include Okubi::CLI::Utils::UserInterface

def kube_client
  @kube_client ||= Kubeclient::Client.new("http://127.0.0.1:8001/api", 'v1')
end

def okapi
  @okapi ||= Okapi::Client.new(configatron.host, 'fs', nil)
end

def dnsimple_client
  # binding.pry
  @dnsimple_client ||= Dnsimple::Client.new(access_token: ENV['DNSIMPLE_TOKEN'])
end

def project_root
  @project_root ||= shell.run!('git rev-parse --show-toplevel').out.strip
end

def apply_from_template(template_file, manifest_name, options={})
  # Store the result of the rendered template in a Tempfile
  # since `kubectl` likes to consume files.
  temp_file = Tempfile.new("#{manifest_name}:#{Time.now.to_i}")

  # Tilt is like MultiJson for templating languages
  template = Tilt::ERBTemplate.new(template_file)
  manifest = template.render(nil, options)

  # Populate, apply, and then destroy the manifest
  temp_file << manifest
  temp_file.flush
  shell.run!("kubectl apply -f #{temp_file.path}")
  temp_file.close
end
