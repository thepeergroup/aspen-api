require 'sinatra'
require 'sinatra/cors'
require 'json'

require 'aspen'

set :allow_origin, "*"
set :allow_methods, "GET,HEAD,OPTIONS,POST"
set :allow_headers, "content-type"

ADAPTERS = Aspen.available_formats.join(',')

get '/' do
  main(params)
end

post '/' do
  request.body.rewind
  data = JSON.parse(request.body.read).symbolize_keys
  main(data)
end

def reformat_node(node)
  node[:type] = node[:label]
  node.delete(:label)
  attributes = node.reject { |k, _| [:id, :type].include?(k) }
  attributes.each { |attr, _| node.delete(attr) }
  node[:attributes] = attributes
  node
end

def main(params)
  code = params.fetch(:code, '')
  adapters = params.fetch(:format, ADAPTERS).split(',').map(&:strip)

  compilation = {}.tap do |set|
    adapters.each do |adapter|
      set[adapter.to_sym] = Aspen.compile_text(code, { adapter: adapter })
    end
  end

  if c = compilation[:json]
    old = JSON.parse(c).deep_symbolize_keys
    new_nodes = old[:nodes].map { |node| reformat_node(node) }
    new_json = old.merge({ nodes: new_nodes })
    compilation[:json] = new_json
  end

  { type: "success" }.merge!(compilation).to_json
rescue Aspen::Error => e
  error_data(e)
rescue Psych::SyntaxError => e
  error_data(e)
end

def error_data(e)
  {
    type: "error",
    error: {
      message: e.message,
      type: e.class
    }
  }.to_json
end
