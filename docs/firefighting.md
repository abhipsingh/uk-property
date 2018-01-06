# Firefighting tools and tips

The application presently lives in a single t2.large AWS instance hosted in ap-south region. 

The application and its dependencies have been listed below
 - PostgreSQL server(9.5)
 - [Ardb](https://github.com/yinqiwen/ardb) A redis plug and play alternative for low memory environments
 - Elasticsearch (2.4.3)
 - Nginx(Open Resty)
 - Unicorn(For creating multiple Ruby processes and listening to UNIX sockets)
 
## Access to the instance

Currently, a `pem` file named as `aws-new-mumbai.pem` needs to be shared with anyone trying to access the instance.

Also an IAM profile needs to be present to access the [AWS web console](https://704247956245.signin.aws.amazon.com). Signin with your username and password and click on EC2 instances.

If you have the `pem` file, the instance can be accessed using

```bash
ssh -i ~/.ssh/aws-new-mumbai.pem ec2-user@13.126.50.230
```

The home folder has a file named as `instance_init.sh`.

To restart all processes simple run


```bash
cd ~/
./instance_init.sh
```

To just restart the unicorn process(loads the new ruby application code), simply run

```bash
cd ~/uk-property
./unicorn_init.sh
```

### Instance data info

There are two volumes mounted on the instance

 - `/` (8 GB..OS, application code..This dies when an instance is terminated
 - `/mnt3/`(100 GB) (Postgres data, Elastic data and Ardb data..All reside here)
 - `/mnt3/postgres_data` contains all the existing tables of PostgreSQL
 - `/mnt3/elasticsearch` contains all the data related to Elastic
 - `/mnt3/ardb` contains all the data for udprns and ardb installation code
 - `/mnt3/royal.csv` (Royal mail property data)
 - `/mnt3/flat_transactions.csv` (All the property historical transactions)

Its also possible to create a new instance with the same application and data as the previous one. However the process is a bit involved.

### Creating a new copy instance to the original one

  - Please create copies of the disk volume `/mnt3` and `/`.
  - Create a new instance in any region and attach those volumes to the instance.
  - Mount those volumes and we can have our data and application back.
  - Install Elasticsearch(2.4.3) and PostgreSQL(9.5)
  - Install Nginx
  - The original nginx conf resided at the location `/usr/local/openresty/nginx/conf/nginx.conf`. Copy this `conf` file to the relevant nginx conf directory.
  - Ardb installation lives in the `mnt3` directory (In future, we'll move to Redis on availability of higher memory instances)
  - Open `sudo vim /var/lib/pgsql94/data/postgresql.conf` and tweak the `data_directory` to the location containing the backed up postgres data.
  - Open `sudo vim /etc/elasticsearch/elasticsearch.yml` and tweak the setting `path.data` and `path.logs` to the relevant data and log location.
  - Start the ardb server(Redis)
    ```bash
    cd /mnt3/ardb/
    ./ardb-server
    ```
  - You can change ardb's settings by changing the value of the setting `data-dir` located inside the file `/mnt3/ardb/ardb.conf`
  - After all the data locations have been configured correctly, simply restart all the processes by running `instance_init.sh`
    ```bash
    ./instance_init.sh ## Location of the file instance_init.sh
    ```

And access the following apis

1) Elasticsearch health monitoring(Needs to be setup properly)
```bash
curl locahost:9200
```

2) Rails apis
```bash
curl localhost
```
 If everything seems fine, the instance copy has completed successfully.
 
### Debugging issues
 
If you logged into the instance successfully, here are some tips on where to look for fixes and what the problems might be.

 - A 500 Status Code for an api (Application code error)
    - The rails logs is located at `/mnt3/rails_logs/production.log`
    - Look for the keyword `Completed 500` after opening the file and start the search from the last instance of the search result. Check if the 500 corresponds to the api which was serving a 500.
    - The error stack trace will be present in the logs for that api
    - Look at the first line of the stack trace which will point to the ruby source file causing an issue.
    - Open the source file, go to the line number and test your luck by retrying the api or reproducing the 500 in some way.
     
 - A 502 (Api timeout)
    - By default Nginx waits for 30 seconds for the unicorn process to return a response before sending a 503. If that api is taking more than 30 seconds(slow api). 
    - Your best bet is to optimise the code for that api(using caching, indexes or segment that api into multiple fragments

 - A 503(Nginx error)
    - This might be a load or an application down issue.

The nginx logs live in the directory
`/var/log/nginx/error.log` and `/var/log/nginx/access.log`

A background job scheduler enabled by [Sidekiq](https://github.com/mperham/sidekiq) can be run using the following command after accessing the rails directory
```bash
cd ~/uk-property 
RAILS_ENV=production bundle exec sidekiq -L /mnt3/rails_logs/sidekiq.log
```

There are three worker classes `QuoteExpiryWorker`, `SoldPropertyUpdateWorker`, `TrackingEmailPropertySoldWorker` and `TrackingEmailStatusChangeWorker` which are triggered frequently.

The workers are set to run on `retry: false` mode. So an error in any of the worker code means that the job is not retried. This may manifest itself into other bugs such as the some attribute not being updated etc.

To see the jobs queued currently, go to the rails console

```bash
cd ~/uk-property
rails c
```
 and in the rails console
```ruby
require 'sidekiq/api'
r = Sidekiq::ScheduledSet.new
jobs = r.select{|job| true }
```

Sometimes the job scheduler might not keep up with the pace of enqueing requests.
In that situation, its better to kill some jobs to process them later.

```bash
jobs.each(&:delete)
```

Sidekiq uses Redis underneath, but since Ardb has a similar interface to Redis, it can also run upon Ardb. The latencies are reasonable but there are times when Ardb doesn't respond quickly. So the `redis_timeout` can be increased in the rails application for the worker to perform those enqueued tasks.

For debugging 500 application errors for apis which are stateless, its also useful to setup local development server on production, place a debugger on the lines producing the error and inspect the variables and data at that point.

```bash
cd ~/uk-property
rails s -p 3001
```

Now, open any file.e.g.
```bash
vim app/models/property_search_api.rb
```

Place debugger at the relevant source line and resolve the issue.

### Apis division

There are nearly 200 Apis that exist in the application. They can all be listed by running
```bash
rake routes
```

Many apis are stateful and a lot are stateless. Meaning, many of them will change the state of the DB, might require a different api call to be executed before them(stateful and capable of modifying). Stateless apis are easier to debug using standard methods but stateful ones are a bit tricky. Listed below are the stateful apis and their flow in brief.

#### Stateful apis

1. `POST 'quotes/new' `(Post events to the server from an agent) is always followed by the following api call
    --> `POST 'quotes/property/:udprn'`(Post new quotes for a property. Done by a vendor)

2. `POST 'events/property/claim/:udprn'`(For an agent, claim this property) is always followed by the following api call
    --> `POST 'properties/udprns/claim/:udprn'`(For any vendor, claim an unknown udprn)

3. `POST 'agents/properties/:udprn/verify'`(Update property details, attach udprn to crawled properties, send vendor email and add assigned agents to properties) is always followed by 
   --> `GET '/agents/:agent_id/udprns/attach/verify''`(List properties and their building details for the agent to tag)

4. `POST vendors/:udprn/verify`(Verify property details, agent_id from the vendor) is always followed by either one of the following
    --> `POST 'agents/properties/:udprn/manual/verify'` (Manually upload property detail for an agent)
    --> `POST 'agents/properties/:udprn/verify`(Discussed above)

5. `POST 'agents/properties/:udprn/manual/verify'` (Update property details, attach udprn to manually added properties, send  vendor email and add assigned agents to properties)
    --> `GET '/agents/:agent_id/udprns/attach/verify'`(List properties and their building details for the agent to tag)

6.  `POST 'properties/vendor/basic/:udprn/update'`(Update basic details of a property by a vendor) is always followed by
    --> `POST 'properties/udprns/claim/:udprn'`(For any vendor, claim an unknown udprn)


### Elasticsearch yml file

The elasticsearch settings have been stored at `/etc/elasticsearch/elasticsearch.yml`. It would be quite useful to know the few of settings and tunables for cases where the elasticsearch search is performing slowly.

```yml
index.search.slowlog.threshold.query.warn: 150ms 
index.search.slowlog.threshold.query.info: 100ms
index.search.slowlog.threshold.query.debug: 300ms
index.search.slowlog.threshold.query.trace: 700ms
index.search.slowlog.threshold.fetch.warn: 150ms
index.search.slowlog.threshold.fetch.info: 100ms
index.search.slowlog.threshold.fetch.debug: 300ms
index.search.slowlog.threshold.fetch.trace: 700ms
index.indexing.slowlog.threshold.index.warn: 150ms
index.indexing.slowlog.threshold.index.info: 100ms
index.indexing.slowlog.threshold.index.debug: 300ms
```
The above settings correspond to enabling logs at various log levels for any elasticsearch operation exceeding the specified time limits.
In the elasticsearch log directory, two files will contain slow logs 
1. `/mnt3/elasticsearch_logs/elasticsearch_index_indexing_slowlog.log`
2. `/mnt3/elasticsearch_logs/elasticsearch_index_search_slowlog.log`

Search for queries which are possible culprits and resolve them (by indexing changes or optimising search queries)

The Gc logs are also of particular interest, as it has happened in the past that the server was unavailable due to multi second old generation GC pauses(CMS) for Elasticsearch

```yml
### GC Log settings
monitor.jvm.gc.young.warn: 1000ms
monitor.jvm.gc.young.info: 700ms
monitor.jvm.gc.young.debug: 400ms

monitor.jvm.gc.old.warn: 10s 
monitor.jvm.gc.old.info: 5s
monitor.jvm.gc.old.debug: 2s
```

Currently the `Xmx` has been set to `4g`.

### Elasticsearch index settings

The index settings can be found at 
```bash
cd ~/uk-property
cat addresses_mapping.json
cat locations_mapping.json
```

There are two indexes in the server

1. `locations` (Stores all the locations for serving auto suggest)
   ```bash
   curl -XGET 'http://localhost:9200/locations/_mapping'
   curl -XGET 'http://localhost:9200/locations/_settings'
   ```
   
2. `addresses`(Stores all the core property attributes like beds, baths etc for searching and filtering capabilities)
    ```bash
       curl -XGET 'http://localhost:9200/addresses/_mapping'
       curl -XGET 'http://localhost:9200/addresses/_settings'
    ```
    This index only contains properties which have a property status of either `Green`,`Red` or `Yellow`







