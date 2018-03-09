# Firefighting tools and tips

The application presently lives in a single r4.large AWS instance hosted in eu-west region. 

The application and its dependencies have been listed below
 - PostgreSQL server(10)
 - [Ardb](https://github.com/yinqiwen/ardb) A redis plug and play alternative for low memory environments
 - Elasticsearch (2.4.3)
 - Nginx
 - Unicorn(For creating multiple Ruby processes and listening to UNIX sockets)
 
## Access to the instance

Currently, a `pem` file named as `aws-london.pem` needs to be shared with anyone trying to access the instance.

Also an IAM profile needs to be present to access the [AWS web console](https://704247956245.signin.aws.amazon.com). Signin with your username and password and click on EC2 instances.

If you have the `pem` file, the instance can be accessed using

```bash
ssh -i ~/.ssh/aws-london.pem ec2-user@35.176.93.242
```

The home folder has a file named as `instance_init.sh`.

To restart all processes simple run


```bash
cd ~/
./instance_init.sh
```

There is also a script named as `startup.sh` located at `/home/ec2-user/startup.sh` which starts the development server, NGINX server, database server and monitoring server in tmux console. The script is automatically run after every reboot.

To just restart the unicorn process(loads the new ruby application code), simply run

```bash
cd ~/uk-property
./unicorn_init.sh stop && ./unicorn_init.sh start
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
  - The original nginx conf resided at the location `/home/ec2-user/uk-property/default.conf`. Copy this `conf` file to the relevant nginx conf directory.
  - Ardb installation lives in the `mnt3` directory (In future, we'll move to Redis on availability of higher memory instances)
  - Open `sudo vim /mnt3/postgres_data/data/postgresql.conf` and tweak the `data_directory` to the location containing the backed up postgres data.
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

There are five worker classes `TrackingEmailWorker`, `QuoteExpiryWorker`, `SoldPropertyUpdateWorker`, `TrackingEmailPropertySoldWorker` and `TrackingEmailStatusChangeWorker` which are triggered frequently.

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

`sidekiq-scheduler` gem is being used to schedule jobs currently for periodic tasks. The config file for this gem can be found at `/home/ec2-user/uk-property/conf/sidekiq.yml`.

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

3. This index only contains properties which have a property status of either `Green`,`Red` or `Yellow`


### Docker testing and environment for easy development workflow

You need to have docker installed on your machine for this. We have four docker images saved in a S3 bucket `prophety-docker-images-dev` and dependent compressed data files all of which need to be downloaded for easy testing.

#### Step 1:
- Download all the docker images which have been listed below
  * [ardb-cache](https://s3.eu-west-2.amazonaws.com/prophety-docker-images-dev/ardb_cache) A substitute for Redis on disk.
  * [Postgres 10](https://s3.eu-west-2.amazonaws.com/prophety-docker-images-dev/app_db) Postgres 10
  * [Elasticsearch 2.4](https://s3.eu-west-2.amazonaws.com/prophety-docker-images-dev/es) Elastic server engine
  * [Prophety-app](https://s3.eu-west-2.amazonaws.com/prophety-docker-images-dev/app_rails) Our Rails application 
 
- Download all the dependent data for the above mentioned images
  * [Ardb Data](https://s3.eu-west-2.amazonaws.com/prophety-docker-images-dev/ardb_data.tar.gz)
  * [Postgres Data](https://s3.eu-west-2.amazonaws.com/prophety-docker-images-dev/postgres_data.tar.gz)
  * [Elasticsearch data](https://s3.eu-west-2.amazonaws.com/prophety-docker-images-dev/es.tar.gz)
- Please ensure that you have disk greater than `15G` in the folder you are downloading.
- Uncompress the data files for `elastic`, `postgres` and `ardb` by using 

```bash
tar xf es.tar.gz
tar xf postgres_data.tar.gz
tar xf ardb_data.tar.gz
```

- Load downloaded docker images by using the following commands

```bash
docker load -i es
docker load -i ardb_cache
docker load -i app_db
docker load -i app_rails
```

- Open [`docker-compose.yml`](https://bitbucket.org/stephenkassi/uk-property/src/c898129c484ac75c7f510aba725640257a42c959/docker-compose.yml?at=master&fileviewer=file-view-default) file present in the root of the application.
- Configure the line which looks like the following for each service `postgres94`, `ardb_cache`, `es24` and `main_app`

```yaml
 volumes:
    - /home/ec2-user/postgres_data/postgres_data/data/:/postgres_data/data/postgres_data/data
```
    
```yaml
 volumes:
   - /home/ec2-user/ardb_data/rocksdb/:/var/lib/ardb/data/rocksdb/
```
    
```yaml
  volumes:
    - /home/ec2-user/elasticsearch/:/usr/share/elasticsearch/data
```

- For each of the volumes listed above, just change the line in such a way that the folder location before `:` is the location of the downloaded data on your machine.

```bash
  $CURRENT_FOLDER/elasticsearch/:/usr/share/elasticsearch/data
```
    
- Now, you need to configure `config/application.yml` file in the rails application folder to assign the parameters
  * Key `ELASTICSEARCH_HOST` : Value `es24` for each `development`, `test` and `production` environment.
  * Key `ARDB_HOST_NAME` : Value `ardb_cache`
- You also need to change the host the file `config/database.yml` in the rails application folder.
   * `host: postgres94` in the `yaml` file for each `development`, `test` and `production` environment.
 
- Finally, the server can be started by using

```bash
docker-compose up
```
   
- Test the api call by executing the following command

```bash
curl -XGET 'http://localhost:3001//addresses/predictions?str=Liverpool'
```

- Also the server can be closed by using

```bash
docker-compose down
```
  
  #### PLEASE NOTE
  - This docker image setup doesn't contain the full production db clone but is sufficient for a quick run on any machine. In case the production db clone is required, the postgres data on production needs to be cloned to the machine.


