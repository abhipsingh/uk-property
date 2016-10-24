require 'cassandra'

def session
  cluster = Cassandra.cluster(hosts: [ENV['CASSANDRA_HOST']], port: 9042)
  keyspace = 'simple'
  cluster.connect(keyspace)
end

Rails.configuration.cassandra_session = session
