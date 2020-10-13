require 'sinatra'
require 'sinatra/cors'
require 'json'

require 'aspen'

set :allow_origin, "*"
set :allow_methods, "GET,HEAD,OPTIONS,POST"
set :allow_headers, "content-type"

get '/' do
  main(params)
end

post '/' do
  request.body.rewind
  data = JSON.parse(request.body.read).symbolize_keys
  main(data)
end

def main(params)
  code = params.fetch(:code, '')

  puts "CODE RECEIVED: #{code.inspect}"

  # TODO: Figure out how to get a discourse
  resp = Aspen.compile_code(code, { adapter: 'json' })
  graph = JSON.parse(resp).deep_symbolize_keys

  new_nodes = graph[:nodes].map do |node|
    node[:type] = node[:label]
    node.delete(:label)
    attributes = node.reject { |k, _| [:id, :type].include?(k) }
    attributes.each { |attr, _| node.delete(attr) }
    node[:attributes] = attributes
    node
  end

  new_graph = graph.merge({ nodes: new_nodes })

  return {
    result: {
      graph: new_graph,
      format: 'json'
    }
  }.to_json
rescue Aspen::Error => e
  return error_data(e)
end

def error_data(e)
  {
    error: {
      message: e.message,
      type: e.class
    }
  }.to_json
end
