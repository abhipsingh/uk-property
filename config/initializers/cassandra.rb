require 'cassandra'

def session
  cluster = Cassandra.cluster(hosts: ['52.66.6.253'], port: 9042)
  keyspace = 'simple'
  cluster.connect(keyspace)
end

Rails.configuration.cassandra_session = session
