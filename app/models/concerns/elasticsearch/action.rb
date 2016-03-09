module Elasticsearch::Action
    extend ActiveSupport::Concern
    included do
        after_find :after_initialize

        def after_initialize
            @index_name = index_name
            @type_name = type_name
            @doc_id = self.id
        end

        def index_name
            self.class.superclass.table_name.pluralize
        end

        def type_name
            self.class.superclass.table_name.singularize
        end

        def default_client(host ="#{Housing.search_server_host}",port = "#{Housing.search_server_host}")
            Elasticsearch::Client.new(host: host,port: port)
        end

        def delete_es_doc(name = nil,type = nil,id = nil)
            client = default_client
            name ||= @index_name
            type ||= @type_name
            id ||= @doc_id
            client.delete index: name, type: type, id: id
        end

        def update_es_doc(name = nil,type = nil,id = nil, data_method = 'as_indexed_json', parent_id=nil)
            client = default_client
            name ||= @index_name
            type ||= @type_name
            id ||= @doc_id
            options_hash = generate_options_hash(name, type, id, parent_id)
            if client.exists options_hash
                options_hash[:body] = {doc: self.send(data_method)}
                response = client.update options_hash
            else
                response = self.index_es_doc
            end
            response["acknowleged"]=="true" ?  true : false
        end

        def generate_options_hash(name, type, id, parent_id)
            options_hash = {
                index: name, 
                type: type,
                id: id
            }
            options_hash[:parent] = parent_id if parent_id
            options_hash
        end

        def index_es_doc(name = nil,type = nil,id = nil)
            client = default_client
            name ||= @index_name
            type ||= @type_name
            id ||= @doc_id
            response = client.index index: name, type: type, id: id,
                body: self.as_indexed_json
        end
    end
    module ClassMethods

        def index_name
            superclass.table_name.pluralize
        end

        def type_name
            superclass.table_name.singularize
        end

        def default_client(host ="#{Housing.search_server_host}",port = "#{Housing.search_server_host}") 
            Elasticsearch::Client.new(host: host,port: port)
        end

        def post_url(host = "#{Housing.search_server_host}",port = "#{Housing.search_server_port}",extension = "/_search",query = {})
            uri = URI.parse(URI.encode("http://#{host}:#{port}#{extension}"))
            query = (query == {}) ? "" : query.to_json
            http = Net::HTTP.new(uri.host, uri.port)
            result = http.post(uri,query)
            body = result.body
            status = result.code
            return body,status
        end
        
        def test_index_name
            index_name + "_test"
        end

        def test_type_name
            type_name + "_test"
        end

        def delete_index(name="")
            client = default_client
            name ||= @index_name
            client.indices.delete index: name
        end

    end

end
