require 'cassandra'

def session
  cluster = Cassandra.cluster
  keyspace = 'simple'
  cluster.connect(keyspace)
end

Rails.configuration.cassandra_session = session