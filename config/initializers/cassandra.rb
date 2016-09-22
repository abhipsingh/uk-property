require 'cassandra'

def session
  cluster = Cassandra.cluster(hosts: ['172.31.5.48'], port: 9042)
  keyspace = 'simple'
  cluster.connect(keyspace)
end

Rails.configuration.cassandra_session = session
